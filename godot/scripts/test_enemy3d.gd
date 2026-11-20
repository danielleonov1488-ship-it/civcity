extends Node
## Боссы, общая 3D-сцена, гибель и нагрузка полного отряда.

const Enemy = preload("res://scripts/legion_enemy_actor.gd")
const View = preload("res://scripts/legion_battle_view.gd")
const PersonLayer = preload("res://scripts/fort_person_layer.gd")
const FortPerson = preload("res://scripts/fort_person.gd")
const OUT := "D:/CivCity/.work/stage7/boss3d_c/shots/"
const STRESS := ["elephant", "chariot", "charioteer", "mercenary", "briton",
	"cataphractFoe", "khopesh", "bear", "gaulArcher", "druid"]

var game: Game
var battle: LegionBattle
var out := OUT
var fails := 0
var squad: Array[Dictionary]
var deaths: Dictionary = {}
var releases: Dictionary = {}


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
	var ids := Enemy.HUMANS.keys() + Enemy.BEASTS.keys() + Enemy.BOSSES.keys()
	for id: String in Legion.ENEMIES:
		check(ids.count(id) == 1, "mapping " + id)
	for id: String in ids:
		check(Legion.ENEMIES.has(id), "unknown key " + id)
	var probe := Node3D.new()
	add_child(probe)
	var modeled := 0
	for id: String in Legion.ENEMIES:
		var actor := Enemy.new()
		probe.add_child(actor)
		if check(actor.build_enemy(id, 0), "3D model %s: %s" % [id, actor.problem]):
			modeled += 1
		_nodes(actor)
		actor.free()
	probe.queue_free()
	print("ENEMY3D ROSTER %d humans %d beasts %d bosses %d sprites" %
		[Enemy.HUMANS.size(), Enemy.BEASTS.size(), Enemy.BOSSES.size(), Legion.ENEMIES.size() - modeled])
	for file: String in DirAccess.get_files_at(Enemy.ASSETS):
		check(_good_name(file), "asset name " + file)
	check(_good_name(Enemy.Boss.HORSE), "mount asset name")
	await _portraits()
	_long_models()
	await _lineup(false)
	_make_squad(game.city.legion)
	await _campaign_ui()
	# Крит, Сицилия и Карфаген входят в прежнюю карту похода.
	Legion.V2 = false
	await _fight("crete", ["bull", "bullLeader", "minotaur", "pirate", "slinger"], "", "", false, "4_crete.png")
	await _fight("sicily", ["pirate", "cyclops", "slinger", "boar"], "")
	await _fight("carthage", ["mercenary", "elephant", "slinger", "pirate"], "2_boss_panel_elephant.png", "elephant")
	Legion.V2 = true
	await _fight("forest", ["forestBear", "forestBear", "forestBear", "bandit"], "", "", false, "2_forest_bears.png")
	await _fight("britannia", ["chariot", "briton", "charioteer", "druid"], "3_boss_panel_charioteer.png", "charioteer")
	await _fight("parthia", ["horseArcher", "cataphractFoe", "cataphract", "numidian", "horseArcher"],
		"4_boss_panel_cataphract.png", "cataphract", false, "5_parthia.png")
	await _fight("africa", ["mercenary", "numidian", "elephant", "hannibal"], "")
	await _fight("africa", STRESS, "", "", true)
	await _lineup(true)
	check(deaths.size() == Enemy.BOSSES.size(), "all seven models fell: %s" % [deaths.keys()])
	check(releases.has("cyclops") and releases.has("horseArcher"), "both releases use the model")


func _portraits() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 80
	add_child(canvas)
	var paper := ColorRect.new()
	paper.color = Color("ead8ba")
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(paper)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.position = Vector2(60, 28)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	paper.add_child(grid)
	var seen := {}
	var ids := Legion.ENEMIES.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return a.nocasecmp_to(b) < 0)
	for id: String in ids:
		var path := Enemy.PORTRAITS + id + ".png"
		if not check(FileAccess.file_exists(path), "portrait file " + id):
			continue
		var u := LegionSim.Unit.new()
		u.side = "enemy"
		u.key = id
		var tex := View.portrait(u)
		if not check(tex != null and tex.resource_path == path, "battle portrait route " + id):
			continue
		var pic := tex.get_image()
		if not check(pic != null and pic.get_size() == Vector2i(256, 256), "portrait size " + id):
			continue
		pic.convert(Image.FORMAT_RGBA8)
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(pic.get_data())
		var digest := hash.finish().hex_encode()
		check(not seen.has(digest), "identical portraits %s and %s" % [id, seen.get(digest, "")])
		seen[digest] = id
		var column := VBoxContainer.new()
		grid.add_child(column)
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(168, 160)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		column.add_child(icon)
		var caption := Label.new()
		caption.text = id
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 21)
		caption.add_theme_color_override("font_color", Color("432b20"))
		column.add_child(caption)
	print("ENEMY3D PORTRAITS %d unique / %d" % [seen.size(), ids.size()])
	await shot("1_portraits_all.png")
	canvas.queue_free()
	await get_tree().process_frame


func _long_models() -> void:
	var view := View.new()
	add_child(view)
	view.size = Vector2(1600, 900)
	view.prewarm()
	var count := 0
	for id: String in Enemy.LONG_MODELS:
		var u := LegionSim.Unit.new()
		u.id = count + 1
		u.side = "enemy"
		u.key = id
		var f := view.add_unit(u)
		if not check(f.actor != null and not f.long_model.is_empty(), "long model " + id):
			continue
		for left: bool in [false, true]:
			f.face(left)
			view._place_actor(f)
			var dir := -1.0 if left else 1.0
			var front: Vector2 = f.long_model[0]
			var muzzle := view._actor_mark(f, Vector3(dir * front.x, 0, front.y))
			check(absf(muzzle.x - f.position.x) < 1.0, "muzzle at contact " + id)
			check((muzzle.x - f.chest().x) * dir > 20.0, "hit within body " + id)
			check(f.head().y < f.chest().y - 30.0, "health bar above body " + id)
			var projectile := LegionSim.Shot.new()
			projectile.target = u
			var sprite := Node2D.new()
			view._place_shot(projectile, sprite, 1.0)
			check(sprite.position.distance_to(f.chest()) < 0.1, "arrow lands on body " + id)
			sprite.free()
		if id == "horseArcher":
			_check_turn(f)
		count += 1
	# В походе дальний проход обычно пуст. Проверяем перекрытие со специально поставленным союзником.
	var cart: View.Fighter = view.views.get(1)
	if check(cart != null, "wide fixture"):
		var soldier := LegionSim.Unit.new()
		soldier.id = 100
		soldier.side = "ally"
		soldier.key = "legionary"
		var rear := view.add_unit(soldier)
		rear.position = Vector2(cart.chest().x, cart.body_ground().y - 26.0)
		view._place_actor(rear)
		_depth_order(view, "rear ally fixture", true)
	view.free()
	print("ENEMY3D CONTACT %d long models, both sides and projectile targets" % count)


func _check_turn(f: View.Fighter) -> void:
	var resting := f.facing_angle()
	f.attack()
	f.attack_left = 0.30
	f.tick(0.075, 1.0, 0.0, true, 0.0)
	var first := absf(f.facing_angle() - resting)
	check(first > 20.0 and first < 35.0, "ease into the shot")
	f.tick(0.225, 1.0, 0.0, true, 0.0)
	check(is_equal_approx(absf(f.facing_angle() - resting), 180.0), "full turn after 0.30 s")
	f.attack_left = 0.0
	f.tick(0.075, 1.0, 0.0, true, 0.0)
	check(is_equal_approx(absf(f.facing_angle() - resting), 180.0 - first), "ease out of the shot")
	f.tick(0.225, 1.0, 0.0, true, 0.0)
	check(is_equal_approx(f.facing_angle(), resting), "normal yaw after 0.30 s")
	print("ENEMY3D YAW %.1f degrees at 0.075 s, 180 at 0.30 s" % first)


func _campaign_ui() -> void:
	var legion := game.city.legion
	var ui := LegionUi.attach(game.hud)
	var progress := legion.progress
	var free_mode := legion.free_mode
	var fort_guide := legion.fort_guide_step()
	var slots := legion.squad3.duplicate()
	legion.free_mode = true
	legion.flags["fort_guide"] = Legion.FortGuide.DONE
	var province := _province("britannia")
	if not check(province >= 0, "Britannia campaign"):
		return
	legion.progress = Legion.stage_index(0, Legion.regions().size() - 1, Legion.stages() - 1)
	var last := Legion.stages() - 1
	game.city.legion_v = 2
	ui.view_c = 0
	ui.view_r = province
	ui.sel = {"c": 0, "r": province, "s": last}
	ui.open("campaign")
	await shot("5_map_boss_cards.png")
	check(_has_portrait(ui.win, "charioteer") and _has_portrait(ui.win, "boudicca"), "map bosses")
	ui.close(false)
	game.city.legion_v = 3
	for i in 3:
		legion.squad3[i] = int(squad[i + 1]["sid"])
	ui.open("campaign")
	ui.open_fort_stage(0, province, Legion.JUNIOR2)
	await shot("6_prep_screen.png")
	var prep := ui.find_child("FortPrepEnemies", true, false)
	check(prep != null and _has_portrait(prep, "charioteer"), "prep roster portrait")
	ui.close(false)
	legion.squad3 = slots
	legion.progress = progress
	legion.free_mode = free_mode
	legion.flags["fort_guide"] = fort_guide


func _has_portrait(root: Node, id: String) -> bool:
	for icon: TextureRect in root.find_children("*", "TextureRect", true, false):
		if icon.is_visible_in_tree() and icon.texture != null and icon.texture.resource_path == Enemy.PORTRAITS + id + ".png":
			return true
	return false


func _province(region: String) -> int:
	for i in Legion.regions().size():
		if Legion.regions()[i].get("id", "") == region:
			return i
	return -1

func _good_name(value: String) -> bool:
	var lower := value.to_lower()
	return not lower.contains("wolf") and not lower.contains("dog")


func _nodes(root: Node) -> void:
	check(_good_name(String(root.name)), "node name " + String(root.name))
	for child: Node in root.get_children():
		_nodes(child)


func _caption(parent: Node, title: String, feet: Vector2, width: float) -> void:
	var caption := Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_color_override("font_color", Color("36221c"))
	caption.add_theme_font_size_override("font_size", 22)
	caption.size.x = width - 18.0
	caption.position = feet + Vector2(-caption.size.x * 0.5, 20.0)
	parent.add_child(caption)


func _lineup(comparison: bool) -> void:
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
	layer.setup("Lineup3D", 7.0)
	layer.fit(area)
	var labels := Node2D.new()
	background.add_child(labels)
	var keys: Array = ["khopesh", "khopesh", "bear", "bear"] if comparison else ["legionary"] + Enemy.BOSSES.keys()
	var widths := PackedFloat32Array([148, 206, 215, 252, 290, 333, 202, 274])
	var slot_x := 0.0
	for i in keys.size():
		var id: String = keys[i]
		var step := area.x / 4.0 if comparison else area.x * widths[i] / 1920.0
		var feet := Vector2(slot_x + step * 0.5, area.y * (0.65 if comparison else 0.60))
		slot_x += step
		if id == "legionary":
			var soldier := FortPerson.make({"id": 21}, layer.viewport, [{"slot": "armor"}], "legionary")
			layer.place(soldier, feet, 131.0, 41.0)
			layer.shadows.append(Vector3(feet.x, feet.y + 2.0, 105.0))
			_caption(labels, I18n.t(String(Legion.UNITS[id]["name"])), feet, step)
			continue
		var actor := Enemy.new()
		actor.name = id
		layer.viewport.add_child(actor)
		if not check(actor.build_enemy(id, 0 if comparison else i), "%s %s" % [id, actor.problem]):
			continue
		var model: Node3D = actor
		if comparison and i == 0:
			actor.pose_at("Idle", 0.10)
			var outfit := actor._rig.get_node("EnemyOutfit")
			for part: Node in outfit.get_children():
				if String(part.name).contains("nemes_flat"):
					part.hide()
			check(actor._add_kit_file("nemes", outfit, actor._atlas, Enemy.ASSETS), "old nemes comparison")
		elif comparison and i == 2:
			actor.hide()
			model = (load(Enemy.ASSETS + "bear.glb") as PackedScene).instantiate() as Node3D
			layer.viewport.add_child(model)
			for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				for surface in mesh.mesh.get_surface_count():
					var material := mesh.get_active_material(surface) as StandardMaterial3D
					mesh.set_surface_override_material(surface, Enemy._animal_skin("bear", material, Enemy.BEASTS["bear"], true))
			var anim := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			anim.play("Idle")
			anim.seek(0.0, true)
		elif comparison and i == 1:
			actor.pose_at("Idle", 0.10)
		elif comparison and i == 3:
			_check_palette(actor, id)
		var visual := 1.0 if comparison else float(Legion.ENEMIES[id].get("size", 1.0)) * actor.size_factor
		var cart := id in ["chariot", "charioteer"]
		var height := (240.0 if comparison else (119.0 if cart else 131.0)) * visual
		var yaw := -30.0 if comparison and i < 2 else (-59.0 if comparison or cart else -actor.yaw)
		var center := 70.0 if cart else (43.0 if id == "elephant" else 0.0)
		var place_at := feet + Vector2(0 if comparison else center, 0)
		layer.shadows.append(Vector3(place_at.x, place_at.y + 2.0, height * (1.24 if actor.wide else 0.68)))
		layer.place(model, place_at, height, yaw)
		var caption := I18n.t(String(Legion.ENEMIES[id]["name"]))
		if comparison:
			caption = ["Немес до", "Немес после", "Медведь до", "Медведь после"][i]
		_caption(labels, caption, feet, step)
	layer.queue_redraw()
	_nodes(layer.viewport)
	var crop := Rect2i(0, 300 if comparison else 255, 1920, 555)
	await shot("8_nemes_bear_fix.png" if comparison else "1_lineup_bosses.png", crop)
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


func _fight(region: String, keys: Array, file: String, boss_id := "", stress := false, field_file := "") -> void:
	var legion := game.city.legion
	var region_index := _province(region)
	if not check(region_index >= 0, "province " + region):
		return
	var troops := squad.duplicate(true)
	var wave := []
	for id: String in keys:
		wave.append(Legion.enemy_stats(id, 1.0))
	for stats: Dictionary in troops + wave:
		stats["hp"] = int(stats["hp"]) * 10
	var last := Legion.JUNIOR2 if Legion.V2 else Legion.stages() - 1
	var stage := legion.stage_info(0, region_index, last)
	var setup := {"kind": "campaign", "stage": stage, "seed": 532,
		"squad": troops, "waves": [wave], "rations_paid": true, "perks": {"oil": 1, "bandage": 1, "volley": 1}}
	var zoom := 1.14 if not file.is_empty() else 1.0
	if not field_file.is_empty():
		zoom = 1.34 if region == "parthia" else 1.26
	battle = LegionBattle.open(game, setup, Callable(), {"legion": legion, "speed": 1.0, "zoom": zoom})
	if not check(await until(func() -> bool: return battle.sim != null and battle.fade.modulate.a <= 0.01, 35), "battle " + region):
		battle.abort()
		return
	var layer := battle.battle_view.people_layer
	var enemies := 0
	var sprites := 0
	var boss_views: Array[View.Fighter] = []
	for view: View.Fighter in battle.views.values():
		if view.unit.side == "ally":
			check(view.actor != null and view.actor.get_parent() == layer.viewport, "ally shared viewport")
		elif view.sprite != null:
			sprites += 1
		elif check(view.actor != null and view.actor.get_parent() == layer.viewport
				and (view.actor.rotation_degrees.y < 0.0 or view.backward_shot()), "3D shared viewport/facing " + view.unit.key):
			enemies += 1
			if Enemy.BOSSES.has(view.unit.key):
				boss_views.append(view)
				check(view.boss_model != null, "composite model " + view.unit.key)
	check(enemies == keys.size() and sprites == 0, "province coverage " + region)
	print("ENEMY3D PROVINCE %s 3D=%d 2D=%d" % [region, enemies, sprites])
	_nodes(layer.viewport)
	_nodes(battle.battle_view.units)
	var ranged := "cyclops" if region == "sicily" else ("horseArcher" if region == "parthia" else "")
	if not ranged.is_empty():
		if check(await until(func() -> bool: return _boss_shot(ranged), 14.0), "projectile from " + ranged):
			var launched_at := battle.sim.t
			await until(func() -> bool: return battle.sim.t >= launched_at + 0.12, 1.0)
	else:
		check(await until(func() -> bool: return battle.sim.t >= 2.75, 14.0), "battle time " + region)
	_depth_order(battle.battle_view, region + (" stress" if stress else ""))
	if not field_file.is_empty():
		var field_time := 5.75 if region == "parthia" else (3.15 if region == "forest" else 3.55)
		check(await until(func() -> bool: return battle.sim.t >= field_time, 8.0), "field shot time " + region)
		_depth_order(battle.battle_view, region + " shot")
	for fighter: View.Fighter in boss_views:
		if fighter.unit.key in ["chariot", "charioteer"] and fighter.boss_model != null:
			check(fighter.boss_model.wheels.size() == 2 and fighter.boss_model.wheel_angle > 0.001,
				"wheels move " + fighter.unit.key)
	if stress:
		await _fps()
		await _close_battle()
	else:
		if boss_id == "charioteer":
			await _contact_shot(boss_id, "1_britannia_contact.png")
		elif boss_id == "elephant":
			await _contact_shot(boss_id, "3_carthage.png")
		if not field_file.is_empty():
			battle.paused = true
			await shot(field_file, Rect2i(220, 202, 1700, 670))
			battle.paused = false
		if not file.is_empty():
			battle.paused = true
			check(battle.boss_panel.visible and battle.boss_pic.texture != null
				and battle.boss_pic.texture.resource_path == Enemy.PORTRAITS + boss_id + ".png", "boss panel portrait " + boss_id)
			await shot(file)
			battle.paused = false
		await _death(boss_views)
	battle.abort()
	await get_tree().process_frame


func _model_bounds(actor: Node3D, camera: Camera3D) -> Array:
	var box := Rect2(camera.unproject_position(actor.global_position), Vector2.ZERO)
	var root_depth := camera.to_local(actor.global_position).z
	var depth := Vector2(root_depth, root_depth)
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or not mesh.is_visible_in_tree():
			continue
		var bounds := mesh.get_aabb()
		for i in 8:
			var point := mesh.to_global(bounds.get_endpoint(i))
			box = box.expand(camera.unproject_position(point))
			var z := camera.to_local(point).z
			depth = Vector2(minf(depth.x, z), maxf(depth.y, z))
	return [box, depth]


func _depth_order(view: View, label: String, require_rear := false) -> void:
	var camera := view.people_layer.camera
	var boxes := {}
	var broad: Array[View.Fighter] = []
	var small: Array[View.Fighter] = []
	for f: View.Fighter in view.views.values():
		if not f.unit.alive or f.actor == null or not f.actor.visible:
			continue
		boxes[f.unit.id] = _model_bounds(f.actor, camera)
		if f.wide:
			broad.append(f)
		else:
			small.append(f)
	var overlaps := 0
	var rear := 0
	for i in broad.size():
		var wide := broad[i]
		var wide_box: Rect2 = boxes[wide.unit.id][0]
		var wide_range: Vector2 = boxes[wide.unit.id][1]
		var wide_feet := wide.body_ground().y
		var wide_depth := camera.to_local(wide.actor.global_position).z
		for j in i:
			check(absf(wide_feet - broad[j].body_ground().y) >= View.WIDE_LANE_STEP - 0.1,
				"separate wide lanes " + label)
		for f: View.Fighter in small:
			var dy := f.body_ground().y - wide_feet
			if f.unit.side == "enemy":
				check(dy > 0.0, "nearer enemy lane %s: %s / %s" % [label, f.unit.key, wide.unit.key])
			if not wide_box.intersects(boxes[f.unit.id][0]) or is_zero_approx(dy):
				continue
			overlaps += 1
			if dy < 0.0:
				rear += 1
				var small_range: Vector2 = boxes[f.unit.id][1]
				check(small_range.y < wide_range.x, "rear model depth %s: %s / %s" % [label, f.unit.key, wide.unit.key])
			var dz := camera.to_local(f.actor.global_position).z - wide_depth
			check(dy * dz > 0.0, "overlap depth %s: %s / %s" % [label, f.unit.key, wide.unit.key])
	check(not broad.is_empty(), "wide actors in " + label)
	check(not require_rear or rear > 0, "rear ally overlaps a wide model")
	print("ENEMY3D DEPTH %s wide=%d overlaps=%d farther_small=%d" % [label, broad.size(), overlaps, rear])


func _boss_shot(key: String) -> bool:
	if releases.has(key):
		return true
	for event: LegionSim.Shot in battle.battle_view.shots:
		if event.from == null or event.from.key != key:
			continue
		var sprite: Node2D = battle.battle_view.shots[event]
		if sprite.has_meta("boss_launch"):
			releases[key] = event.kind
			print("ENEMY3D RELEASE ", key, " ", event.kind)
			return true
	return false


func _melee() -> View.Fighter:
	for f: View.Fighter in battle.views.values():
		var u := f.unit
		if u.side == "ally" and u.alive and not u.ranged() and u.target != null and u.target.alive:
			var foe: View.Fighter = battle.views.get(u.target.id)
			if foe != null and foe.wide and foe.boss_model != null and f.clip == f.attack_clip:
				return f
	return null


func _close_battle() -> void:
	if not check(await until(func() -> bool: return _melee() != null, 12.0), "close-up against a wide boss"):
		return
	battle.paused = true
	var ally := _melee()
	var enemy: View.Fighter = battle.views[ally.unit.target.id]
	var view := battle.battle_view
	_depth_order(view, "africa close fight")
	var feet := view.screen(ally.position).lerp(view.screen(enemy.position), 0.5)
	var height := maxf(ally.body_height(), enemy.body_height()) * view.world.scale.y
	var crop := Rect2i(Vector2i(feet - Vector2(675.0, height * 1.08 + 160.0)), Vector2i(1350, int(height * 1.17 + 240.0)))
	await shot("7_close_fight.png", crop)
	battle.paused = false


func _at_contact(key: String) -> View.Fighter:
	for f: View.Fighter in battle.views.values():
		var u := f.unit
		if u.key != key or not u.alive or u.entering or u.target == null or not u.target.alive:
			continue
		var ally: View.Fighter = battle.views.get(u.target.id)
		if ally == null:
			continue
		var reach := u.range_m + 0.35 * (u.size + u.target.size - 2.0)
		var gap := (f.contact_point().x - ally.position.x) * (1.0 if f.flip_h else -1.0)
		if LegionSim.dist(u, u.target) <= reach + 0.12 and absf(gap - 48.0 * ally.scale.x) <= 14.0:
			return f
	return null


func _contact_shot(key: String, file: String) -> void:
	if not check(await until(func() -> bool: return _at_contact(key) != null, 14.0), "front touches the line " + key):
		for f: View.Fighter in battle.views.values():
			var u := f.unit
			if u.key == key and u.target != null:
				var ally: View.Fighter = battle.views.get(u.target.id)
				print("ENEMY3D CONTACT ", key, " t=", battle.sim.t, " clip=", f.clip, " facing left=", f.flip_h,
					" distance=", LegionSim.dist(u, u.target), " reach=", u.range_m, " placement=", f.position,
					" adjusted=", f.contact_point(), " ally=", ally.position if ally != null else Vector2.ZERO)
		return
	battle.paused = true
	var f := _at_contact(key)
	var ally: View.Fighter = battle.views.get(f.unit.target.id)
	var view := battle.battle_view
	var center := view.screen(f.contact_point().lerp(f.body_ground(), 0.36))
	var crop := Rect2i(roundi(center.x) - 680, 202, 1360, 670)
	_depth_order(view, key + " contact")
	print("ENEMY3D CONTACT ", key, " gap=", snappedf(absf(f.contact_point().x - ally.position.x), 0.1), " px")
	await shot(file, crop)
	battle.paused = false

func _fps() -> void:
	check(battle.views.size() == 15, "5 allies and 10 enemies including the elephant and two chariots")
	check(get_viewport().get_texture().get_size() == Vector2(1920.0, 1080.0), "FPS resolution")
	var start := Time.get_ticks_usec()
	for i in 120:
		await get_tree().process_frame
	var fps := 120000000.0 / maxf(1.0, Time.get_ticks_usec() - start)
	check(battle.views.size() == 15, "all 15 combatants at end of FPS sample")
	var viewport := battle.battle_view.people_layer.viewport
	var draws := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var triangles := viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	print("ENEMY3D FPS %.1f at %dx%d, %d draws, %d triangles" % [fps, viewport.size.x, viewport.size.y, draws, triangles])
	check(fps >= 60.0, "60 FPS budget")


func _death(fighters: Array[View.Fighter]) -> void:
	var fallen := {}
	for view: View.Fighter in fighters:
		if check(view.unit.alive, "live model before kill " + view.unit.key):
			fallen[view.unit.id] = view.unit.key
			battle.sim._hurt(view.unit, view.unit.hp + 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	for id: int in fallen:
		var view: View.Fighter = battle.views.get(id)
		check(view != null and not view.unit.alive and view.clip == view.death_clip and view.death > 0.0,
			"death starts on sim kill " + String(fallen[id]))
	for id: int in fallen:
		if check(await until(func() -> bool: return not battle.views.has(id), 3.0), "fallen model hides " + String(fallen[id])):
			deaths[fallen[id]] = true
			print("ENEMY3D DEATH ", fallen[id])
