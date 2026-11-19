extends Node
## Проверки и кадры LEGION9. Сохранение проверяется в памяти.

const Kit = preload("res://scripts/ui_kit_a.gd")
const Fixture = preload("res://scripts/test_fort_fixture.gd")
const FortPerson = preload("res://scripts/fort_person.gd")
const Actor = preload("res://scripts/charpilot_actor.gd")
const PersonLayer = preload("res://scripts/fort_person_layer.gd")
const BattleView = preload("res://scripts/legion_battle_view.gd")
const SHOTS := "D:/CivCity/.work/stage7/legion9b/shots/"

var out := SHOTS
var game: Game
var lg: Legion
var camp: CampUI
var view: FortCutaway
var battle: LegionBattle
var fails := 0
var saved_clock := 0.0
var graphics := true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").replace("\\", "/").trim_suffix("/") + "/"
	graphics = DisplayServer.get_name() != "headless"
	if graphics:
		get_window().content_scale_size = Vector2i.ZERO
		get_window().size = Vector2i(1920, 1080)
	saved_clock = Legion.clock
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.can_save = false
	game.hero_screen_auto = false
	add_child(game)
	_run()


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func check(ok: bool, reason: String) -> bool:
	if not ok:
		fails += 1
		print("LEGION9 FAIL ", reason)
	return ok


func finish() -> void:
	if is_instance_valid(battle) and LegionBattle.current == battle:
		battle.abort()
	Legion.clock = saved_clock
	print("LEGION9 DONE fails=", fails)
	get_tree().quit(int(fails > 0))


func shot(file: String, layer: PersonLayer, crop := Rect2i()) -> void:
	if not graphics:
		return
	await frames(8)
	await RenderingServer.frame_post_draw
	var people := layer.viewport.get_texture().get_image()
	var drawn := 0
	if people != null and not people.is_empty():
		check(people.get_pixel(2, 2).a < 0.1, "прозрачность 3D-слоя " + file)
		for x in range(4, people.get_width(), 8):
			for y in range(4, people.get_height(), 8):
				if people.get_pixel(x, y).a > 0.4:
					drawn += 1
	check(drawn >= 8, "фигуры видны в 3D-слое " + file)
	var path := out.path_join(file)
	var image := get_viewport().get_texture().get_image()
	if crop.has_area() and image != null:
		image = image.get_region(crop.intersection(Rect2i(Vector2i.ZERO, image.get_size())))
	if check(image != null and not image.is_empty() and image.save_png(path) == OK, "кадр " + file):
		print("LEGION9 SHOT ", path)


func _fixture() -> int:
	var city: City = game.city
	city.cozy_v = 1
	city.legion_v = 3
	city.level = 5
	city.name = "Нова Рома"
	city.hero = Hero.make("Гай Валерий", 0, Hero.PRESETS[0]["look"], true, 777)
	lg = city.legion
	lg.fort = {}
	lg.camp = {}
	lg.soldiers.clear()
	lg.items.clear()
	lg.upg.clear()
	lg.flags["camp_open"] = true
	lg.flags["camp_told"] = true
	lg.flags["fort_guide"] = Legion.FortGuide.DONE
	lg.squad3 = [0, 0, 0, 0, 0]
	lg._rng.seed = 912711
	lg.time_k = 1.0
	Legion.clock = Time.get_unix_time_from_system()
	lg.army_tick()
	for type: String in ["hq", "barracks", "kitchen", "forge", "treasury"]:
		Fixture.set_level(lg, type, 2)
	lg.fort["money"] = 2840.0
	lg.fort["know"] = {}
	lg.mats = {"wood": 100.0, "iron": 100.0, "leather": 100.0}
	lg.ingots = 18
	lg.glory = 120
	lg.rations = 12
	lg.progress = 2
	lg.chest_queue = ["wooden", "bronze"]
	Fixture.gate(lg, 1)
	var newcomer: Dictionary = lg.fort_newcomers()[0]
	var identity: Dictionary = newcomer.get("look", {}).duplicate()
	var person := lg.fort_accept(int(newcomer["id"]))
	if not check(not person.is_empty() and not identity.is_empty() and person.get("look") == identity, "облик переходит от ворот к жителю"):
		return 0
	person["name"] = "Аврелий"
	var sid := int(person["id"])
	var kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	var treasury := int(lg.fort_slot_plot("treasury")["id"])
	check(lg.fort_assign(treasury, sid) and lg.fort_assign(kitchen, sid) and person["look"] == identity, "переезд между комнатами сохраняет пол, лицо и волосы")
	for role: String in ["forge", "treasury", "drill"]:
		var worker := lg._add_soldier({"name": "Юлий", "cls": "legionary"})
		var plot := lg.fort_slot_plot(role)
		check(not plot.is_empty() and lg.fort_assign(int(plot["id"]), int(worker["id"])), "работник для " + role)
	for i in range(1, 3):
		var soldier := lg._add_soldier({"name": "Тит", "cls": "legionary"})
		var soldier_id := int(soldier["id"])
		var kind := "bow" if i == 2 else "sword"
		var weapon := lg.add_item(Gear.craft_item(kind, 1))
		check(lg.equip(soldier_id, int(weapon["id"])) and Fixture.house_fighter(lg, soldier_id)
			and lg.set_place(i, soldier_id), "боец отряда " + kind)
		if i == 1:
			for slot: String in ["armor", "helmet", "offhand"]:
				var item := lg.add_item(Gear.craft_item(slot, 1))
				check(lg.equip(soldier_id, int(item["id"])), "боевое снаряжение " + slot)
	Fixture.gate(lg, 2)
	return sid


func _save_restore(sid: int, apron_id: int) -> void:
	var original: Dictionary = lg.soldier(sid)["look"].duplicate()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(lg.to_dict()))
	lg.from_dict(saved.duplicate(true))
	check(lg.soldier(sid).get("look") == original and int(lg.soldier(sid)["gear"][Gear.OUTFIT_SLOT]) == apron_id
		and Gear.work_kind(lg.item(apron_id)) == "cook", "JSON сохраняет облик и рабочую одежду")
	var legacy := saved.duplicate(true)
	for person: Dictionary in legacy["soldiers"]:
		if int(person["id"]) == sid:
			person.erase("look")
	for i in 2:
		lg.from_dict(legacy.duplicate(true))
		check(lg.soldier(sid).get("look") == original, "одинаковый облик из старого сохранения, проход %d" % i)
	lg.from_dict(saved.duplicate(true))


func _outfit_examples(sid: int, apron: Dictionary, smith: Dictionary) -> void:
	if not graphics:
		return
	var display := CanvasLayer.new()
	display.layer = 100
	add_child(display)
	var area := get_viewport().get_visible_rect().size
	var room := TextureRect.new()
	room.size = area
	room.texture = load(FortCutaway.room_texture_path("barracks", 4)) as Texture2D
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	display.add_child(room)
	var layer := PersonLayer.new()
	display.add_child(layer)
	layer.setup("OutfitExamples3D", 14.0)
	layer.fit(area)
	var outfits := [[], [apron], [smith]]
	var names := [I18n.t("Крестьянин"), Gear.name_of(apron), Gear.name_of(smith)]
	var person := lg.soldier(sid)
	for i in outfits.size():
		var x := area.x * (0.23 + float(i) * 0.27)
		var actor := FortPerson.make(person, layer.viewport, outfits[i])
		var feet := Vector2(x, area.y * 0.84)
		actor.pose_at("Idle", 0.24)
		layer.place(actor, feet, area.y * 0.52, 14.0)
		layer.shadows.append(Vector3(feet.x, feet.y, area.y * 0.52))
		var label := Kit.ribbon(names[i])
		label.position = Vector2(x - 170.0, area.y * 0.89)
		label.size.x = 340.0
		display.add_child(label)
	layer.queue_redraw()
	await shot("4_outfit_change.png", layer)
	display.queue_free()


func _fps() -> void:
	if not graphics:
		print("LEGION9 SKIP FPS headless")
		return
	for i in FortCutaway.SPRITE_LIMIT:
		lg._add_soldier({"name": "Луций", "cls": "legionary", "female": i % 2 == 1})
	view.sync()
	check(view.figures.size() == FortCutaway.SPRITE_LIMIT - 1, "не больше 40 фигур с учётом призрака")
	await frames(30)
	var started := Time.get_ticks_usec()
	await frames(120)
	var fps := 120000000.0 / maxf(1.0, Time.get_ticks_usec() - started)
	print("LEGION9 FPS %.1f (фигур %d)" % [fps, view.figures.size()])
	var vp := view.people_layer.viewport
	var draws := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var triangles := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
	print("LEGION9 3D %dx%d draws=%d triangles=%d" % [vp.size.x, vp.size.y, draws, triangles])
	check(fps >= 55.0, "не меньше 55 кадров/с при 1920×1080")


func _fight() -> void:
	var squad := lg.squad_v3()
	var wave := []
	for kind: String in ["bandit", "gaul", "bear", "gaulArcher"]:
		wave.append(Legion.enemy_stats(kind, 1.0))
	var setup := {"kind": "campaign", "stage": lg.stage_info(0, 0, 0), "seed": 322,
		"squad": squad, "waves": [wave, wave, wave, wave, wave], "rations_paid": true,
		"perks": {"oil": 1, "bandage": 1, "volley": 1}}
	battle = LegionBattle.open(game, setup, Callable(), {"legion": lg, "speed": 1.0})
	var started := Time.get_ticks_msec()
	while (battle.sim == null or battle.fade.modulate.a > 0.01) and Time.get_ticks_msec() - started < 20000:
		await frames(1)
	if not check(battle.sim != null and battle.fade.modulate.a <= 0.01, "бой открылся"):
		return
	var count := 0
	var archer := false
	var hero := false
	for f: BattleView.Fighter in battle.views.values():
		if f.unit.side == "enemy":
			check(f.sprite is AnimatedSprite2D and f.actor == null, "враг использует B1-спрайт")
			continue
		count += 1
		var person := lg.soldier(f.unit.sid)
		if check(f.actor != null and f.actor.problem.is_empty() and f.sprite == null
				and f.actor.get_parent() == battle.battle_view.people_layer.viewport, "наш боец в общем 3D-слое"):
			check(not person.is_empty() and f.actor.get_meta("look") == person.get("look"), "тот же житель в бою")
			if f.unit.key == "archer" and f.actor.has_outfit("archer"):
				archer = true
				var bow := f.actor.find_child("ArcherBow", true, false) as Node3D
				var quiver := f.actor.find_child("outfit_archer_quiver", true, false) as Node3D
				var grip := bow.get_parent().get_parent() as BoneAttachment3D if bow != null else null
				check(grip != null and grip.bone_name == "LeftHand" and bow.is_visible_in_tree()
					and quiver != null and quiver.is_visible_in_tree(), "лук у левой кисти, колчан на спине")
			check(f.actor.rotation_degrees.y > 0.0 and not f.flip_h, "союзники смотрят вправо на старте")
			hero = hero or f.unit.key == "hero" and f.actor.has_outfit("centurion")
	check(count == squad.size() and archer and hero, "лучник и центурион в отряде")
	while battle.sim.t < 3.5 and Time.get_ticks_msec() - started < 25000:
		await frames(1)
	var allies: Array[BattleView.Fighter] = []
	var crop := Rect2()
	for f: BattleView.Fighter in battle.views.values():
		if f.actor == null or not f.unit.alive:
			continue
		check(f.actor.rotation_degrees.y > 0.0 and not f.flip_h, "в бою союзники смотрят вправо")
		for ally: BattleView.Fighter in allies:
			var gap := (f.position - ally.position).abs()
			check(gap.x >= 75.0 or gap.y >= 40.0, "у союзников раздельные силуэты")
		allies.append(f)
		var feet := battle.battle_view.screen(f.position)
		var height := f.body_height() * battle.battle_view.world.scale.y
		var figure := Rect2(feet - Vector2(height * 0.56, height * 1.14), Vector2(height * 1.12, height * 1.21))
		crop = crop.merge(figure) if crop.has_area() else figure
	check(allies.size() == squad.size(), "в кадре есть весь отряд")
	battle.paused = true
	await shot("5_battle.png", battle.battle_view.people_layer)
	if crop.has_area():
		await shot("6_battle_close.png", battle.battle_view.people_layer, Rect2i(crop.grow(16.0)))


func _run() -> void:
	var start := Time.get_ticks_msec()
	while not game.ready_done and Time.get_ticks_msec() - start < 240000:
		await frames(5)
	if not check(game.ready_done, "ready_done timeout"):
		finish()
		return
	game.can_save = false
	game.settings["autosave"] = false
	game.hud.set_speed(0.0)
	if graphics and not check(DirAccess.make_dir_recursive_absolute(out) == OK, "папка кадров"):
		finish()
		return
	var sid := _fixture()
	if sid == 0:
		finish()
		return
	camp = CampUI.of(game.hud)
	if not check(is_instance_valid(camp), "окно форта"):
		finish()
		return
	camp.open()
	await frames(8)
	view = camp.diorama as FortCutaway
	if not check(is_instance_valid(view), "разрез форта"):
		finish()
		return
	var layer := view.people_layer
	var entry := view._find_person(sid, false)
	var actor := entry.get("node") as Actor
	if not check(actor != null and actor.problem.is_empty() and actor.get_parent() == layer.viewport
			and actor.has_outfit("peasant"), "житель в крестьянской одежде в общем 3D-слое"):
		finish()
		return
	var meshes: Array[MeshInstance3D] = actor.identity.duplicate()
	for other: Dictionary in view.figures:
		check(other["node"] is Actor and other["node"].get_parent() == layer.viewport, "нет спрайтов жителей")
		var room: Rect2 = view.room_rects.get(other["plot"], Rect2())
		if room.has_area():
			var height := float(other["height"])
			var home: Vector2 = other["home"]
			var away := Vector2(float(other["away"]), home.y)
			check(height >= room.size.y * 0.50 and height <= room.size.y * 0.56
				and room.has_point(home) and room.has_point(away)
				and home.y - height >= room.position.y, "житель в пределах комнаты")
	var person := lg.soldier(sid)
	var kitchen := int(lg.fort_slot_plot("kitchen")["id"])
	var p := lg.fort_plot(kitchen)
	var base_stats := lg.soldier_stats(person, "legionary")
	p["pend"] = 0.0
	p["t"] = Legion.now() - 120.0
	lg.fort_finish()
	var base_output := float(p["pend"])
	var apron := lg.add_item(Gear.craft_item("cook", 1))
	var apron_id := int(apron["id"])
	check(lg.equip(sid, apron_id), "надеть фартук")
	p["pend"] = 0.0
	p["t"] = Legion.now() - 120.0
	lg.fort_finish()
	check(float(p["pend"]) > base_output and is_equal_approx(float(p["pend"]), base_output * 1.15), "фартук даёт +15% к выпуску кухни")
	check(lg.soldier_stats(person, "legionary") == base_stats, "рабочий бонус не передаётся в бой")
	view.sync()
	check(view._find_person(sid, false).get("node") == actor and actor.has_outfit("cook")
		and actor.identity == meshes and actor.get_meta("look") == person["look"], "сменились узлы одежды, лицо и волосы те же")
	_save_restore(sid, apron_id)
	person = lg.soldier(sid)
	var forge := int(lg.fort_slot_plot("forge")["id"])
	check(lg.can_craft(forge, "smith", 1) == Legion.SMITH_LOCK, "одежда требует Кузнечное знание")
	check(lg.learn_smith() and not lg.craft_start(forge, "smith", 1), "рабочая одежда требует отдельного знания")
	Fixture.set_level(lg, "hq", 3)
	check(lg.learn("outfit"), "изучение рабочей одежды")
	Legion.clock += lg.knowledge_seconds("outfit") + 1.0
	lg.fort_finish()
	check(lg.craft_start(forge, "smith", 1), "запуск рецепта одежды в кузнице")
	Legion.clock += float(Gear.TIER_TIME[0]) + 1.0
	var smith := lg.craft_collect(forge)
	if not check(Gear.work_kind(smith) == "smith", "готовый фартук кузнеца"):
		finish()
		return
	check(lg.equip(int(lg.fort_worker(forge)["id"]), int(smith["id"])) and lg.fort_work_speed(forge, "forge") > 1.0, "фартук ускоряет кузницу")
	camp._refresh()
	await shot("1_fort.png", layer)
	view.begin_person_move(sid, false, view.project(forge))
	check(is_instance_valid(view.drag_ghost) and view.drag_ghost.get_parent() == layer.viewport
		and view.drag_ghost.get_meta("look") == person["look"] and view.drag_ghost.has_outfit("cook")
		and view.drag_ghost._opacity < 1.0, "прозрачный призрак той же модели и одежды")
	await shot("2_drag.png", layer)
	view.cancel_person_move()
	camp.show_dweller(sid, Gear.OUTFIT_SLOT)
	var preview := camp.modal_panel.find_child("FortPortraitArt", true, false) as FortPersonPreview
	if check(preview != null and preview.actor.get_meta("look") == person["look"] and preview.actor.has_outfit("cook")
			and camp.modal_panel.find_child("FortOutfitBonus", true, false) != null, "живой портрет и бонус в карточке"):
		await shot("3_dweller_card.png", preview.layer)
	camp._close_modal()
	check(lg.unequip(sid, Gear.OUTFIT_SLOT), "снять фартук")
	view.sync()
	check(actor.has_outfit("peasant") and actor.identity == meshes, "после снятия та же модель крестьянина")
	await _outfit_examples(sid, lg.item(apron_id), smith)
	await _fps()
	camp.close()
	await frames(2)
	await _fight()
	finish()
