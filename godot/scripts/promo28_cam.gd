extends "res://scripts/promo27_cam.gd"
## Повторная съёмка. Настройки камеры и декорации действуют только в этой сцене.

const PromoRise = preload("res://scripts/promo28_rise.gd")
const SHOT_DIR := "D:/CivCity/.work/stage7/promo28/shots"
const PHONE_UI_SCALE := 1.4
const PHONE_VIEWS := {
	"road_drag": [Vector3(201, 0.3, 115), 56.0, 47.0, 25.0],
	"three_houses": [Vector3(191, 1.3, 120), 59.0, 42.0, 27.0],
	"move_in": [Vector3(193, 0.9, 99), 10.0, 32.0, 18.0],
	"fruit_stall": [Vector3(183, 0.9, 115.2), -27.0, 47.0, 23.0],
	"hire": [Vector3(198, 1.0, 112), 15.0, 32.0, 13.0],
	"floor": [Vector3(187, 2.5, 121), -22.0, 29.0, 13.0],
	"garden": [Vector3(198, 0.5, 121.7), 14.0, 39.0, 14.0],
	"fountain": [Vector3(201, 1.0, 121.7), -21.0, 34.0, 13.0],
	"requests": [Vector3(187, 0.8, 112), 15.0, 36.0, 14.0],
	"research": [Vector3(191, 1.0, 112), 21.0, 37.0, 15.0],
	"arena_build": [Vector3(207, 1.9, 140), 34.0, 46.0, 34.0],
}

var rise: PromoRise
var fight_focus := 0.0
var fight_peak := 0


func _clip_config(name: String) -> Dictionary:
	if name == "cityrise":
		return {
			"dur": 20.0, "warm": 3.0, "life": 12.0, "hour": [12.0, 17.55],
			"blur": 0.0, "ease": "inout", "fov": 35.0,
			"keys": [[0, Vector3(190, 0, 157), -19, 66, 123],
				[20, Vector3(194, 0, 166), 18, 50, 108]],
			"v": {"fov": 36.0, "dist": 1.07},
		}
	var cfg := super._clip_config(name)
	if vertical and PHONE_VIEWS.has(name):
		var v: Array = PHONE_VIEWS[name]
		cfg["keys"] = [[0, v[0], v[1], v[2], v[3]]]
		cfg["v"] = {"fov": 34.0}
	return cfg


func _boot_args(hour: float) -> Dictionary:
	var boot := super._boot_args(hour)
	boot["shot"] = SHOT_DIR.path_join("unused.png")
	if clip_name == "cityrise":
		boot.erase("new")
		boot["promo"] = "1"
		boot["noui"] = "1"
	return boot


func _setup(full: bool) -> void:
	if clip_name == "cityrise":
		game.weather.force = 0.0
		rise = PromoRise.new()
		rise.prepare(game)
		if rise.buildings.size() < 100:
			_fail("не загрузился витринный город")
		return
	super._setup(full)


func _setup_gameplay() -> void:
	if vertical and PHONE_VIEWS.has(clip_name):
		game.settings["ui_scale"] = PHONE_UI_SCALE
		hud.apply_scale(PHONE_UI_SCALE)
	super._setup_gameplay()
	if vertical and PHONE_VIEWS.has(clip_name):
		cursor.position = get_viewport().get_visible_rect().size * Vector2(0.68, 0.55)
		cursor.scale = Vector2.ONE * 1.18
		if clip_name == "fountain":
			game.clear_nature(Vector2(201, 122), 5.5)


func _build_at(t: float, type: String, p: Vector2) -> void:
	# После лесов оставляем время показать струи готового фонтана.
	if vertical and clip_name == "fountain":
		t -= 0.85
	super._build_at(t, type, p)


func _aim(p: Vector2) -> void:
	if not vertical or not PHONE_VIEWS.has(clip_name):
		super._aim(p)
		return
	if is_instance_valid(cursor_tween):
		cursor_tween.kill()
	var width := get_viewport().get_visible_rect().size.x
	var seconds := clampf(cursor.position.distance_to(p) / (width * 0.75), 0.45, 0.96 if clip_name == "road_drag" else 1.25)
	cursor_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cursor_tween.tween_property(cursor, "position", p, seconds)


func _aim_control(control: Control) -> void:
	if is_instance_valid(control) and control.is_visible_in_tree():
		_aim(control.get_global_transform_with_canvas() * (control.size * 0.5))


func _phone_panel(panel: Control, pivot: Vector2) -> void:
	var cap := get_window().content_scale_factor
	var total_width := hud.root.size.x - 30.0
	var scale := maxf(1.0, minf(PHONE_UI_SCALE / cap, total_width / maxf(panel.size.x, 1.0)))
	panel.pivot_offset = panel.size * pivot
	panel.scale = Vector2.ONE * scale


func _phone_panels() -> void:
	# Полосы остаются в штатных пределах. Карточки можно увеличить до предела ползунка.
	_phone_panel(hud.tasks_panel, Vector2.ZERO)
	_phone_panel(hud.tool_panel, Vector2.ONE)
	_phone_panel(hud.info_panel, Vector2(1, 0))
	_phone_panel(hud.research_panel, Vector2(0.5, 0.5))
	_phone_panel(hud.road_panel, Vector2(0, 1))


func _setup_legion() -> void:
	if clip_name != "battle":
		super._setup_legion()
		return
	cursor.hide()
	var legion: Legion = city.legion
	var rng := RandomNumberGenerator.new()
	rng.seed = 28
	city.hero = Hero.random(rng, 0)
	var stage := legion.stage_info(0, 2, 5)
	var setup := legion.make_battle(stage, 28)
	setup.erase("tutorial")
	var hero := Legion.hero_unit_stats(3, 4, 2)
	hero["hero"] = true
	var squad: Array[Dictionary] = [hero]
	for type: String in ["legionary", "legionary", "archer", "cavalry", "priest"]:
		squad.append(Legion.unit_stats(type, 3))
	var gauls: Array[Dictionary] = []
	for type: String in ["vercingetorix", "gaul", "gaul", "gaul", "gaulArcher", "druid", "boar"]:
		gauls.append(Legion.enemy_stats(type, 1.05))
	# Запас здоровья удерживает обе стороны в кадре до конца клипа.
	for unit: Dictionary in squad + gauls:
		unit["hp"] = roundi(float(unit["hp"]) * 2.7)
	setup["squad"] = squad
	setup["waves"] = [gauls]
	setup["packs"] = []
	setup["hero_look"] = Hero.battle_look(city, 2)
	battle = LegionBattle.open(game, setup, Callable(), {"speed": 1.0})


func _gate() -> bool:
	if clip_name == "battle":
		return super._gate() and battle.sim.t >= 3.6
	return super._gate()


func _pose(t: float) -> void:
	if vertical and PHONE_VIEWS.has(clip_name):
		_phone_panels()
	super._pose(t)
	if clip_name != "battle" or not _gate():
		return
	var view := battle.battle_view
	var sum := 0.0
	var count := 0
	var weights := 0.0
	for f: LegionBattleView.Fighter in view.views.values():
		if f.unit.alive and absf(f.position.x) < 570.0:
			var weight := 2.5 if f.unit.key == "hero" or f.unit.boss else 1.0
			sum += (view.screen(f.position).x - view.size.x * 0.5) * weight
			weights += weight
			count += 1
	fight_peak = maxi(fight_peak, count)
	if weights > 0.0:
		fight_focus = lerpf(fight_focus, sum / weights, 0.036)
	var magnify := (2.08 if vertical else 1.72) + smoothstep(0.0, dur, t) * 0.12
	view.scale = Vector2.ONE * magnify
	view.pivot_offset = Vector2(view.size.x * 0.5, view.world.position.y)
	var shift := Vector2(-fight_focus * magnify, view.size.y * 0.59 - view.world.position.y)
	view.position = shift
	battle.ui.hide()


func _events(t: float) -> void:
	if clip_name == "cityrise":
		rise.advance(t, game)
		if t >= 19.0 and not rise.finished():
			_fail("город не дорос до витрины")
		return
	super._events(t)
	if clip_name == "battle" and t >= 11.0 and (fight_peak < 8 or battle.phase not in ["intro", "fight"]):
		_fail("фаза %s, в кадре до %d бойцов" % [battle.phase, fight_peak])


func _fail(reason: String) -> void:
	push_error("PROMO28 FAIL %s: %s" % [clip_name, reason])
	get_tree().quit(2)
