extends Node3D
## Городские правила, замеры моделей и снимки без сохранения города игрока.

const BlackProbe := preload("res://scripts/test_black.gd")
const IDS := ["arch", "colosseum", "pantheon", "trajan", "circus", "aqueduct", "caracalla", "jupiter"]
const NEW := ["circus", "aqueduct", "caracalla", "jupiter"]
const POLISHED := ["caracalla", "jupiter"]
const SIZES := {"circus": Vector2(36, 14), "aqueduct": Vector2(24, 6), "caracalla": Vector2(16, 16), "jupiter": Vector2(12, 18)}
const PRICES := {"arch": 7250, "colosseum": 32500, "pantheon": 64000, "trajan": 40000,
	"circus": 50000, "aqueduct": 45000, "caracalla": 70000, "jupiter": 90000}
const RANKS := {"circus": 5, "aqueduct": 5, "caracalla": 6, "jupiter": 7}
const NEEDS := {"circus": ["fun"], "aqueduct": ["services"], "caracalla": ["services", "fun"], "jupiter": ["faith"]}
const POS := {"circus": Vector2(159, 192), "aqueduct": Vector2(206, 187), "caracalla": Vector2(159, 225),
	"jupiter": Vector2(207, 225), "trajan": Vector2(183, 207)}
var out := "D:/CivCity/.work/stage7/wonders7b/shots/"
var game: Game
var city: City
var fails := 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			out = arg.trim_prefix("out=").trim_suffix("/") + "/"
	Game.boot = {"new": "1", "hour": "11"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	game.hero_screen_auto = false
	add_child(game)
	game.can_save = false
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, message: String) -> bool:
	print(("WONDERS7 PASS " if ok else "WONDERS7 FAIL ") + message)
	if not ok:
		fails += 1
	return ok


func _finish() -> void:
	print("WONDERS7 DONE fails=%d" % fails)
	game.queue_free()
	await frames(2)
	get_tree().quit(0 if fails == 0 else 1)


func _run() -> void:
	var waited := 0
	while not game.ready_done and waited < 18000:
		await frames(5)
		waited += 5
	if not check(game.ready_done, "game ready"):
		_finish()
		return
	game.can_save = false
	game.settings["autosave"] = false
	game.speed = 0.0
	game.weather.force = 0.0
	if game.tutorial.active():
		game.tutorial.step = Tutorial.STEPS.size()
		game.tutorial.card.hide()
	city = game.city
	_skip_goals(city)
	city.tips["tut"] = -1
	city.tips["ui"] = 3
	game.hud.apply_reveal(3)
	game.hud.advisor_panel.hide()
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot folder"):
		_finish()
		return
	_city_rules()
	_credits()
	await _probe_models()
	await _views()
	_finish()


func _skip_goals(c: City) -> void:
	for goal: Dictionary in Defs.REQUESTS:
		if not c.goals_done.has(goal["id"]):
			c.goals_done.append(goal["id"])


func _flatten(c: City, a: Vector2, z: Vector2) -> void:
	var lo := c.land.cell(a)
	var hi := c.land.cell(z)
	var cells := PackedInt32Array()
	for j in range(lo.y, hi.y):
		for i in range(lo.x, hi.x):
			cells.append(c.land.idx(i, j))
	c.land.flatten_cells(cells, Land.BASE_Y, Land.Kind.GRASS)


func _road(c: City, type: String, at: Vector2, half_width := 15.0) -> void:
	var p := Catalog.make(type, 0).door
	var center := at + Vector2(p.x, p.z + 1.02)
	c.land.paint_line(center - Vector2(half_width, 0), center + Vector2(half_width, 0), 0.80, Land.Kind.ROAD, true)


func _city_rules() -> void:
	var c := City.new(Land.new())
	_skip_goals(c)
	var at := Vector2(157, 205)
	_flatten(c, Vector2(132, 178), Vector2(253, 235))
	var near := c.place("house_pleb", at + Vector2(22, 0), 0.0, 0, 0, true)
	var far := c.place("house_pleb", at + Vector2(91, 0), 0.0, 0, 0, true)
	c.research["research1"] = true
	c.arrivals_paused = true
	var visible: Array = game.hud._types_in("special", "wonders")
	check(visible.size() == IDS.size() and IDS.all(func(t: String) -> bool: return visible.has(t)), "eight visible wonder entries")
	for type: String in IDS:
		var def: Dictionary = Defs.B[type]
		var tech := Defs.research(type)
		var cost := float(tech["cost"])
		c.level = int(tech["lvl"])
		if type in NEW:
			check(c.level == int(RANKS[type]), type + " correct rank")
		var prereq := String(tech.get("after", ""))
		if prereq != "":
			c.research[prereq] = true
		c.rp = cost
		c.money = 150000.0
		check(not c.unlocked(type) and c.place(type, at, 0.0).is_empty(), type + " blocked before research")
		check(c.do_research(type) and c.unlocked(type) and is_zero_approx(c.rp), type + " research unlocks and costs points")
		_road(c, type, at)
		var money := c.money
		var glory := c.legion.glory + c.legion.glory_acc
		var army := c.legion.stats("legionary")
		var place_err := String(c.check_place(type, at, 0.0)["err"])
		var b := c.place(type, at, 0.0)
		if not check(not b.is_empty(), type + " placed" + (": " + place_err if not place_err.is_empty() else "")):
			continue
		check(is_equal_approx(money - c.money, float(PRICES[type])) and is_equal_approx(c.legion.glory + c.legion.glory_acc, glory),
			type + " exact denarii debit")
		check(c.legion.stats("legionary") == army, type + " no army stat bonus")
		if type in NEW:
			check(float(near["monuments"]) == float(def["bonus"]) and is_zero_approx(float(far["monuments"])),
				type + " happiness only within radius")
			for need: String in NEEDS[type]:
				check(int(near["need_coverage"][need]) == 100 and int(far["need_coverage"][need]) == 0,
					"%s %s covered only within radius" % [type, need])
			c.money = 150000.0
			check(c.check_place(type, at + Vector2(50, 0), 0.0)["err"] == "Такая постройка в городе уже есть",
				type + " unique in city")
			var cells: PackedInt32Array = b["cells"]
			check(not cells.is_empty() and c.land.occ[c.land.idx(c.land.cell(at).x, c.land.cell(at).y)] == int(b["id"])
				and c.apron_of(b) == 3, type + " occupied and paved")
			for i in 24:
				c.sim_day()
			check(is_equal_approx(c.legion.glory + c.legion.glory_acc - glory, float(def["glory_day"])), type + " daily glory")
		c.remove(b, false)
		var door := Catalog.make(type, 0).door
		var line := at + Vector2(door.x, door.z + 1.02)
		c.land.paint_line(line - Vector2(15, 0), line + Vector2(15, 0), 0.80, Land.Kind.GRASS, true)


func _credits() -> void:
	var c := City.new(Land.new())
	_skip_goals(c)
	var data := c.save_data()
	data["wonders_v"] = 1
	data["wonder_credits"] = {"circus": 1, "aqueduct": 1, "caracalla": 1, "jupiter": 1}
	c.load_data(JSON.parse_string(JSON.stringify(data)))
	_flatten(c, Vector2(130, 177), Vector2(244, 245))
	c.money = 0.0
	for type: String in NEW:
		var at: Vector2 = POS[type]
		_road(c, type, at)
		check(c.unlocked(type) and c.wonder_credit_ready(type) and not c.research.has(type)
			and c.build_price(type) == 0.0, type + " saved credit opens early")
		check(c.place(type, Vector2.ZERO, 0.0).is_empty() and c.wonder_credit_ready(type),
			type + " invalid location leaves credit intact")
		var b := c.place(type, at, 0.0)
		if check(not b.is_empty(), type + " saved credit placed free"):
			check(c.money == 0.0 and not c.wonder_credit_ready(type) and c.refund_price(b) == 0.0,
				type + " consumes one right, no cash on demolition")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.save_data()))
	c.load_data(saved)
	check(c.wonder_credits.is_empty() and NEW.all(func(t: String) -> bool: return c.count_type(t) == 1), "four free wonders persist; rights stay spent")


func _probe_models() -> void:
	# Отдельный мир с той же группировкой Parts, без неба, земли, травы и интерфейса.
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(640, 360)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.MAGENTA
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("ece5d6")
	env.environment.ambient_light_energy = 0.48
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53, -31, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	vp.add_child(sun)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	var probe := BlackProbe.new()
	for type: String in NEW:
		var bp := Catalog.make(type, 0)
		var lot: Rect2 = bp.footprint()[0]
		var fit: bool = lot.size.is_equal_approx(SIZES[type])
		var overhang := 0.0
		var far_part := ""
		for part: Array in bp.parts:
			var xf: Transform3D = part[1]
			var ab: AABB = xf * Bp.model_aabb(part[0])
			var over_x := maxf(lot.position.x - ab.position.x, ab.end.x - lot.end.x)
			var over_z := maxf(lot.position.y - ab.position.z, ab.end.z - lot.end.y)
			var excess := maxf(over_x, over_z)
			if excess > overhang:
				overhang = excess
				far_part = String(part[0])
		check(fit and overhang <= 0.06, "%s fits %.0f×%.0f m (overhang %.3f m %s)" % [type, lot.size.x, lot.size.y, overhang, far_part])
		var parts := Parts.new()
		vp.add_child(parts)
		parts.place(bp, Transform3D.IDENTITY)
		var ctr := Vector3.UP * bp.top_y() * 0.42
		var draws := 0
		var tris := 0
		var shadow_draws := 0
		var black := 0
		for i in 4:
			var yaw := PI * 0.25 + PI * 0.5 * i
			cam.look_at_from_position(ctr + Vector3(sin(yaw), 0.49, cos(yaw)) * maxf(lot.size.length() * 1.16, 16.0), ctr)
			await frames(3)
			await RenderingServer.frame_post_draw
			draws = maxi(draws, vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
			tris = maxi(tris, vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
			shadow_draws = maxi(shadow_draws, vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
			black += probe._analyze(vp.get_texture().get_image(), "")
		print("WONDERS7 PERF %s draws=%d triangles=%d shadow_draws=%d black_px=%d" % [type, draws, tris, shadow_draws, black])
		check(draws > 0 and draws < 250 and tris > 0, type + " render budget")
		check(black == 0, type + " no connected black opening across four sides")
		check(bp.lights.size() >= 3, type + " blueprint night lights")
		parts.queue_free()
		await frames(2)
	probe.free()
	vp.queue_free()


func _put_in_town(type: String, at: Vector2, yaw := 0.0, variant := 0) -> Dictionary:
	var b := city.place(type, at, yaw, variant, 0, true)
	if not check(not b.is_empty() and not (b["cells"] as PackedInt32Array).is_empty(), "visual fixture " + type):
		return {}
	game.clear_nature_cells(b["cells"])
	if type == "house_pleb":
		b["tier"] = 2
	game._show(b)
	return b


func _street(a: Vector2, b: Vector2) -> void:
	var cells := PackedInt32Array()
	for change: Array in city.land.paint_line(a, b, 0.80, Land.Kind.ROAD, true):
		var p: Vector2i = change[0]
		cells.append(city.land.idx(p.x, p.y))
	game.clear_nature_cells(cells)


func _shot(file: String) -> void:
	await frames(12)
	await RenderingServer.frame_post_draw
	if check(get_viewport().get_texture().get_image().save_png(out + file) == OK, "saved " + file):
		print("WONDERS7 SHOT " + out + file)


func _views() -> void:
	_flatten(city, Vector2(134, 173), Vector2(232, 242))
	var landmarks := {}
	for type: String in NEW + ["trajan"]:
		city.research[type] = true
		var at: Vector2 = POS[type]
		_road(city, type, at, 18.0 if type == "circus" else 13.0)
		landmarks[type] = _put_in_town(type, at)
		if (landmarks[type] as Dictionary).is_empty():
			return
	_street(Vector2(178.7, 191), Vector2(178.7, 235))
	_street(Vector2(173, 200), Vector2(178.7, 200))
	_street(Vector2(178.7, 191), Vector2(206, 191))
	_street(Vector2(169, 234), Vector2(178.7, 234))
	_street(Vector2(178.7, 235), Vector2(199, 235))
	var homes := [Vector2(142, 203), Vector2(170, 204), Vector2(182, 196), Vector2(188, 187),
		Vector2(196, 195), Vector2(220, 194), Vector2(222, 185), Vector2(145, 225), Vector2(153, 235),
		Vector2(168, 235), Vector2(173, 221), Vector2(197, 225), Vector2(216, 236), Vector2(222, 225), Vector2(205, 237)]
	for i in homes.size():
		_put_in_town("house_pleb", homes[i], PI if i % 3 == 0 else 0.0, i % 2)
	city.compute()
	var rid := int(landmarks["circus"]["id"])
	var spec: Spectacle = game.spectacle
	var venue: Dictionary = spec.venues[rid]
	game._set_hour(11.25)
	check(spec._phase_of(venue) == "show" and not (venue["lay"]["seats"] as Array).is_empty(), "circus has scheduled race and fitted seats")
	spec.force(rid, "show", 0.29, true)
	spec._enter_phase(venue, "show")
	var act: CircusShow = venue["act"]
	if check(act.chariots.size() == 2 and spec.count(rid) > 0, "circus draws two chariots and seats spectators"):
		for step in 240:
			act.tick(0.10, "show")
		check(int(act.chariots[0]["lap"]) >= 1, "circus completes a lap")
	var baths: Dictionary = landmarks["caracalla"]
	var steam: Array = game.visuals[baths["id"]]["smoke"]
	var emitting := steam.all(func(p: GPUParticles3D) -> bool: return p.emitting)
	var hall_y := Land.BASE_Y + 3.0
	var hall_steam := steam.filter(func(p: GPUParticles3D) -> bool: return p.position.y > hall_y)
	check(emitting and steam.size() == 4 and hall_steam.size() == 2,
		"Caracalla emits steam from two hall windows and two pool sources")
	var bath_bp := city.blueprint(baths)
	var windows := bath_bp.parts.filter(func(part: Array) -> bool: return part[0] == "#plate_lit")
	check(windows.size() >= 12, "Caracalla hall and wings have lit window backings")
	game.hud.close_panels()
	game.hud.visible = false
	for type: String in NEW:
		var at: Vector2 = POS[type]
		var size: Vector2 = SIZES[type]
		var top := city.blueprint(landmarks[type]).top_y()
		var dist := maxf(size.x * 1.13, size.y * 1.69) + 5.6
		game.rig.set_view(Vector3(at.x, Land.BASE_Y + top * 0.51, at.y), 26.0, 28.0, dist)
		game.grass.fill_now()
		game._set_hour(11.25)
		if type == "aqueduct":
			var fnt := game.get_node("Fountains") as Fountains
			fnt._scan = 0.0
			await frames(12)
			check(fnt.jets.has(landmarks[type]["id"]), "castellum spout has a water emitter")
		if type in POLISHED:
			await _shot(type + "_day.png")
		if type == "circus":
			spec._enter_phase(venue, "idle")
		game._set_hour(23.0)
		var lights: Array = game.visuals[landmarks[type]["id"]]["lights"]
		check(lights.any(func(light: OmniLight3D) -> bool: return light.visible), type + " actual nighttime lamps")
		if type == "caracalla":
			var lamp_color := Interiors.material(true).albedo_color
			check(lamp_color.r > lamp_color.b + 0.12, "Caracalla window interiors are warm at night")
		if type in POLISHED:
			await _shot(type + "_night.png")
	game._set_hour(11.25)
	game.rig.set_view(Vector3(183, Land.BASE_Y + 3.0, 207), 0.0, 53.0, 108.0)
	await _shot("all_far.png")
	var hud: Hud = game.hud
	hud.show()
	city.level = 5
	city.money = 90000.0
	hud.refresh()
	for type: String in ["aqueduct", "caracalla", "jupiter"]:
		city.research.erase(type)
	city.wonder_credits["aqueduct"] = 1
	hud.open_ssub = "wonders"
	hud._toggle_cat("special")
	var waited := 0
	while not IDS.all(func(t: String) -> bool: return hud.icons.has(t)) and waited < 2200:
		await frames(4)
		waited += 4
	hud._fill_cards()
	check(hud.tray_grid.get_child_count() == 8 and IDS.all(func(t: String) -> bool: return hud.icons.has(t)),
		"eight wonder cards with rendered icons")
	for b: Button in hud.tray_grid.get_children():
		var type := String(b.get_meta("type", ""))
		var img := b.find_child("img", true, false) as TextureRect
		check(img != null and (img.material != null) == (not city.unlocked(type)), type + " card lock tint follows availability")
		if not city.unlocked(type):
			check(String(Defs.research(type)["name"]) in b.tooltip_text, type + " lock names its research")

