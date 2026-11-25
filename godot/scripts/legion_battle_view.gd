class_name LegionBattleView
extends Control

const Perf14 = preload("res://scripts/perf14_timers.gd")
const Perf13 = preload("res://scripts/perf13_timers.gd")
## Рисованное поле боя. Читает позы и события LegionSim, не меняет состояние боя.

signal field_sound(event: String, pan: float)
signal melee_pose(source: Fighter, target: Fighter)
signal melee_event(source: Fighter, target: Fighter)

# Фигуры мельче поля, как в Hustle Castle: между бойцами остаётся воздух.
const FIGURE_SCALE := 0.52
const REAR_X := 657.0
# Бой занимает широкую полосу луга, а не узкую тропу: бойцам есть где разойтись по глубине.
const TRAIL_DEPTH := [106.0, 112.0, 116.0, 124.0]

const FortPerson = preload("res://scripts/fort_person.gd")
const Actor = preload("res://scripts/charpilot_actor.gd")
const Enemy = preload("res://scripts/legion_enemy_actor.gd")
const Boss = preload("res://scripts/legion_boss_model.gd")
const RangedPose = preload("res://scripts/legion_ranged_pose.gd")
const PersonLayer = preload("res://scripts/fort_person_layer.gd")
const ART := "res://assets/legion_b1/"
const DESIGN := Vector2(1600, 900)
const CELL := 256
const BASELINE := 242
const PEOPLE_TILT := 5.0
const WIDE_LANE_Y := -118.0
const WIDE_LANE_STEP := 48.0
const PEOPLE_DEPTH := 1024.0
const PEOPLE_FRAME := 1.0 / 120.0
const DISPLAY_GAIN := 7.0
# Бойцы занимают всю ширину тропы в глубину, как в Hustle Castle, а не узкую полосу посередине.
const DEPTH_SCALE := 40.0
# Бойцы стоят там, где их поставил расчёт боя; картинка только плавно ведёт фигуры.
const SIM_POSITIONS := true
const DISPLAY_ACCEL := 6.0
const FIELDS := {"forest": 2, "darkforest": 2, "swamp": 3, "labyrinth": 4,
	"rocks": 4, "desert": 4, "hades": 4}
const TRAIL_Y := [0.718, 0.710, 0.743, 0.714]
const ALLIES := {"legionary": "legionary", "spearman": "legionary", "archer": "archer",
	"ballista": "archer", "catapult": "archer", "priest": "priest", "cavalry": "cavalry", "hero": "hero"}
# Центр и верх силуэта на листах B1.
const SILHOUETTE := {"legionary": Vector2(100, 8), "archer": Vector2(124, 8),
	"priest": Vector2(129, 8), "cavalry": Vector2(121, 19), "hero": Vector2(99, 8),
	"barbarian_warrior": Vector2(113, 20), "barbarian_archer": Vector2(84, 8),
	"barbarian_chief": Vector2(120, 8), "bear": Vector2(135, 77)}
const ALERT := Color("f76539")
const GOLD := Color("ffe088")
const HEAL := Color("acf78c")

static var _frames := {}

var field: TextureRect
var legion: Legion
var pvp := false
var hero_look: Dictionary = {}
var enemy_hero_look: Dictionary = {}
var people_layer: PersonLayer
var world := Node2D.new()
var units := Node2D.new()
var effects := Node2D.new()
var ground := GroundLayer.new()
var views := {}
var shots := {}
var _bursts: Array[Burst] = []
var _flights: Array[Flight] = []
var _enemy_variants := {}
var _stone: Texture2D
var _trail_y := 0.72
var _trail_depth := 51.0
var _field_bounds := Rect2()
var _fighters: Array[Fighter] = []
var _wide_fighters: Array[Fighter] = []
var _cluster_lanes := {}
var _mounted_line_edge := INF
var _mounted_front_min := -INF
var _layout_step := -1
var _layout_time := 0.0
var _layout_sim_time := 0.0
# Старый кадр для сравнения и замера скорости.
var legacy_layout := false
var _zoom := 1.0
var _people_time := 0.0
var _dead_ids: Array[int] = []
var _done_shots: Array[LegionSim.Shot] = []
var profile_poses := false
var pose_usec := 0
var windup_usec := 0


func _ready() -> void:
	clip_contents = true
	field = TextureRect.new()
	field.name = "BattleField"
	field.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	field.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)
	world.name = "BattleWorld"
	add_child(world)
	world.add_child(ground)
	people_layer = PersonLayer.new()
	people_layer.name = "AlliedPeople"
	add_child(people_layer)
	people_layer.setup("BattlePeople3D", PEOPLE_TILT)
	people_layer.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	units.z_index = 2
	effects.z_index = 3
	people_layer.z_index = 1
	units.name = "BattleUnits"
	units.y_sort_enabled = true
	world.add_child(units)
	world.add_child(effects)
	ground.views = views
	resized.connect(_fit)
	_fit()


static func opening_art(biome: String) -> Dictionary:
	var paths := {ART + "battle/field_%d.jpg" % int(FIELDS.get(biome, 1)): true}
	for sheet: String in SILHOUETTE:
		if not _frames.has(sheet):
			paths[ART + "chars/%s.png" % sheet] = true
	for kind: String in ["fx_hit", "fx_heal", "fx_arrow"]:
		if not _frames.has(kind):
			paths[ART + "battle/%s.png" % kind] = true
	paths["res://assets/ui/ai/icons/rock.png"] = true
	return paths


func set_field(biome: String) -> void:
	var index := int(FIELDS.get(biome, 1))
	field.texture = load(ART + "battle/field_%d.jpg" % index)
	_trail_y = TRAIL_Y[index - 1]
	_trail_depth = TRAIL_DEPTH[index - 1]
	_fit()


func set_zoom(value: float) -> void:
	if not legacy_layout:
		var ratio := clampf(_zoom, 0.94, 1.07) / clampf(value, 0.94, 1.07)
		for f in _fighters:
			f.scale *= ratio
			f.measure_body()
	_layout_step = -1
	_zoom = value
	_fit()


func _fit() -> void:
	var cover_h := maxf(size.y, size.x * 1080.0 / 2560.0)
	var path_y := size.y * 0.5 + (_trail_y - 0.5) * cover_h
	world.position = Vector2(size.x * 0.5, minf(path_y, size.y * 0.79))
	var design_scale := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	world.scale = Vector2.ONE * maxf(0.001, design_scale / (_zoom if legacy_layout else 1.0))
	var half := size.x * 0.5 / world.scale.x
	_field_bounds = Rect2(-half, -_trail_depth, half * 2.0, _trail_depth * 2.0)
	if legacy_layout:
		people_layer.fit(size)
	else:
		# ?? ????????? ???? ?????? ?????????? ???? ????.
		people_layer.fit(size, Rect2(0.0, world.position.y - world.scale.y * 444.0,
			size.x, world.scale.y * (486.0 + _trail_depth)))
	people_layer.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	for id in views:
		var f: Fighter = views[id]
		_place_actor(f)


static func point(x: float, z: float) -> Vector2:
	# Поперечные ряды немного сдвинуты вбок, чтобы бойцы одного строя были видны.
	var px := x * 73.0 + z * 126.0
	if absf(px) > 530.0:
		px = signf(px) * (530.0 + (absf(px) - 530.0) * 0.27)
	return Vector2(px, z * 43.0)


func screen(p: Vector2) -> Vector2:
	return world.position + p * world.scale


func sound_pan(where: Vector2) -> float:
	var width := maxf(1.0, size.x)
	return clampf(screen(where).x / width, 0.0, 1.0) * 1.2 - 0.6


static func melee_sound(source: LegionSim.Unit, target: LegionSim.Unit, now: float) -> String:
	var gear: Array = Enemy.HUMANS.get(source.key, [])
	var weapon := String(gear[1]) if not gear.is_empty() else ""
	if weapon in ["axe", "falx"] or source.key in ["bull", "bullLeader", "elephant"] or "giant" in source.tags:
		return "hit_heavy"
	if weapon in ["club", "cudgel", "staff"]:
		return "hit_wood"
	if target.testudo > now or "armored" in target.tags or target.key in ["legionary", "spearman", "hero"]:
		return "hit_metal"
	var shield: Array = Enemy.HUMANS.get(target.key, [])
	if (not shield.is_empty() and String(shield[2]) in ["oval", "round", "hex"]) or "beast" in source.tags:
		return "hit_wood"
	return "hit_metal"


static func sheet_id(u: LegionSim.Unit) -> String:
	if u.side == "enemy":
		# Медведи, включая лесного, ядовитого и подземных, используют лист B1.
		if "beast" in u.tags:
			return "bear"
		if u.boss:
			return "barbarian_chief"
		if not Legion.UNITS.has(u.key) and u.key != "hero":
			return "barbarian_archer" if u.ranged() else "barbarian_warrior"
	return String(ALLIES.get(u.key, "priest" if u.heal_pow > 0.0 else ("archer" if u.ranged() else "legionary")))


static func portrait(u: LegionSim.Unit) -> Texture2D:
	if u.side == "enemy":
		var enemy := Enemy.portrait_texture(u.key)
		if enemy != null:
			return enemy
	return load(ART + "chars/%s_portrait.png" % sheet_id(u))


static func _atlas_frame(tex: Texture2D, index: int, pixels: int) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = tex
	frame.region = Rect2(index * pixels, 0, pixels, pixels)
	frame.filter_clip = true
	return frame


static func _animation(frames: SpriteFrames, tex: Texture2D, id: StringName, first: int, count: int,
		pixels: int, fps: float, loop: bool) -> void:
	frames.add_animation(id)
	frames.set_animation_speed(id, fps)
	frames.set_animation_loop(id, loop)
	for i in range(first, first + count):
		frames.add_frame(id, _atlas_frame(tex, i, pixels))


static func _unit_frames(sheet: String) -> SpriteFrames:
	if not _frames.has(sheet):
		var tex: Texture2D = load(ART + "chars/%s.png" % sheet)
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		_animation(frames, tex, &"idle", 0, 2, CELL, 2.5, true)
		_animation(frames, tex, &"walk", 2, 4, CELL, 9.0, true)
		_animation(frames, tex, &"attack", 6, 2, CELL, 8.0, false)
		_frames[sheet] = frames
	return _frames[sheet] as SpriteFrames


static func _effect_frames(kind: String) -> SpriteFrames:
	if not _frames.has(kind):
		var tex: Texture2D = load(ART + "battle/%s.png" % kind)
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		_animation(frames, tex, &"effect", 0, 4, 128, 12.0, false)
		_frames[kind] = frames
	return _frames[kind] as SpriteFrames


func prewarm(waves: Array = []) -> void:
	# Листы будущих волн и эффекты готовим под занавесом.
	var tree := get_tree()
	var started := Perf14.begin()
	var deadline := Time.get_ticks_usec() + 4000
	for atlas: String in SILHOUETTE:
		_unit_frames(atlas)
		if Time.get_ticks_usec() >= deadline:
			Perf14.end(Perf14.BATTLE_FIELD, started)
			await tree.process_frame
			started = Perf14.begin()
			deadline = Time.get_ticks_usec() + 4000
	for kind: String in ["fx_hit", "fx_heal", "fx_arrow"]:
		_effect_frames(kind)
	_stone = load("res://assets/ui/ai/icons/rock.png")
	Perf14.end(Perf14.BATTLE_FIELD, started)
	await tree.process_frame
	await Enemy.prewarm(waves, tree)


func add_unit(u: LegionSim.Unit) -> Fighter:
	if views.has(u.id):
		return views[u.id] as Fighter
	var f := Fighter.new()
	f.name = "Fighter_%d" % u.id
	f.unit = u
	f.sheet = sheet_id(u)
	f.silhouette = SILHOUETTE[f.sheet]
	f.scale = Vector2.ONE * clampf(u.size * 1.08, 0.82, 1.54)
	f.lane_z = u.z
	f.health = u.hp_frac()
	units.add_child(f)
	if pvp and u.side == "enemy" and u.key == "hero":
		f.actor = Actor.new()
		f.actor.name = "Enemy_%d" % u.id
		people_layer.viewport.add_child(f.actor)
		var chosen := enemy_hero_look if not enemy_hero_look.is_empty() else Hero.rival_look(u.src)
		var clips := f.actor.build_rival_hero(chosen, u.id)
		f.idle_clip = String(clips["idle"])
		f.walk_clip = String(clips["walk"])
		f.attack_clip = String(clips["attack"])
		f.hit_clip = String(clips["hit"])
		f.death_clip = String(clips["death"])
		f.clip = f.idle_clip
		if u.shot == "arrow":
			f.actor.equip_ranged("bow")
	elif u.side == "ally" or (pvp and Legion.UNITS.has(u.key)):
		var person := _ally_person(u) if u.side == "ally" else {}
		if person.is_empty():
			person = {"id": u.id, "hero": u.key == "hero"}
			if u.side == "ally" and u.key == "hero" and not hero_look.is_empty():
				person["female"] = int(hero_look.get("sx", 0)) == 1
				person["look"] = hero_look
		var gear: Array = legion.worn(person) if legion != null and u.side == "ally" else []
		f.actor = FortPerson.make(person, people_layer.viewport, gear, u.key)
		f.actor.name = ("%s_%d" % ["Ally" if u.side == "ally" else "Enemy", u.id])
		var loadout: Dictionary = f.actor.get_meta("loadout")
		if u.heal_pow > 0.0:
			f.actor.equip_ranged("cast")
		elif u.key == "slinger" or u.shot == "sling":
			f.actor.equip_ranged("sling")
		elif u.shot == "arrow":
			f.actor.equip_ranged("bow")
		f.idle_clip = "Sword_Idle" if bool(loadout["sword"]) else "Idle"
		f.clip = f.idle_clip
		f.hit_clip = "Hit_Chest"
		f.death_clip = "Death01"
	else:
		_add_enemy(f)
	if f.actor != null and not f.actor.problem.is_empty():
		f.actor.free()
		f.actor = null
	if f.actor != null and f.actor.ranged != null:
		f.idle_clip = f.actor.ranged.idle_clip()
		f.attack_clip = f.actor.ranged.action_clip()
		f.release_time = f.actor.ranged.release_time
		f.clip = f.idle_clip
		if f.boss_model == null and f.actor.ranged.mode == "bow":
			f.yaw = 67.0
	if f.actor == null:
		f.sprite = AnimatedSprite2D.new()
		f.sprite.name = ("EnemySprite" if u.side == "enemy" else "AllySprite")
		f.sprite.sprite_frames = _unit_frames(f.sheet)
		f.add_child(f.sprite)
		f.sprite.play(&"idle")
	if u.side == "enemy":
		var occupied := {}
		for other: Fighter in views.values():
			if other.wide:
				occupied[other.wide_lane] = true
			if other.unit.side == "enemy" and other.unit.wave == u.wave:
				other.in_wide_wave = other.in_wide_wave or f.wide
				f.in_wide_wave = f.in_wide_wave or other.wide
		if f.wide:
			while occupied.has(f.wide_lane):
				f.wide_lane += 1
	f.view = self
	if not legacy_layout:
		f.scale *= FIGURE_SCALE / clampf(_zoom, 0.94, 1.07)
	f.face(u.side == "enemy" and (not u.entering or u.enter_dir < 0.0))
	f.measure_body()
	f.position = f.layout_point(u.x, u.z)
	if not legacy_layout:
		f.position = _fit_foot(f, f.position)
	_place_actor(f)
	views[u.id] = f
	_fighters.append(f)
	_layout_step = -1
	if not legacy_layout and f.mounted_line:
		# Расставляем подкрепление и обновляем 3D-слой в том же кадре.
		_layout_time = 1.0 / 60.0
		_people_time = 1.0 / 80.0
	return f


func _add_enemy(f: Fighter) -> void:
	var u := f.unit
	var model := Enemy.new()
	model.name = "Enemy_%d" % u.id
	model.set_meta("enemy_id", u.key)
	people_layer.viewport.add_child(model)
	var variant := int(_enemy_variants.get(u.key, u.id % 2))
	_enemy_variants[u.key] = 1 - variant
	if model.build_enemy(u.key, u.id, variant):
		f.actor = model
		f.scale = Vector2.ONE * clampf(u.size * 1.08 * model.size_factor, 0.82, 2.18)
		f.actor_height = model.stature
		f.wide = model.wide
		f.boss_model = model.boss_model
		f.long_model = Enemy.LONG_MODELS.get(u.key, [])
		f.yaw = model.yaw
		f.idle_clip = model.idle
		f.walk_clip = model.walk
		f.attack_clip = model.strike
		f.hit_clip = model.reaction
		f.death_clip = model.fall
		f.clip = f.idle_clip
		f.sample = float(u.id % 6) * 0.13
	else:
		if not model.problem.is_empty():
			push_warning("Legion enemy %s: %s" % [u.key, model.problem])
		model.free()


func _ally_person(u: LegionSim.Unit) -> Dictionary:
	if legion == null:
		return {}
	var person: Dictionary = legion.soldier(u.sid) if u.sid > 0 else {}
	if person.is_empty() and u.key == "hero":
		for resident: Dictionary in legion.soldiers:
			if bool(resident.get("hero", false)):
				return resident
	return person


func _place_actor(f: Fighter, rate := 1.0, force_pose := false) -> void:
	if not is_instance_valid(f.actor):
		return
	f.drawn_foot = f.body_ground()
	var feet := screen(f.drawn_foot)
	var height := f.model_height() * world.scale.y
	var frame := Rect2(Vector2.ZERO, size).grow(height)
	var long := not f.long_model.is_empty()
	f.actor.visible = f.modulate.a > 0.0 and (frame.has_point(feet) or (long and frame.has_point(screen(f.contact_point()))))
	if f.actor.visible or long:
		# Ортокамера сохраняет проекцию. Разнос по глубине не даёт длинным моделям пересечь соседний ряд.
		var depth := (clampf(feet.y / maxf(size.y, 1.0), 0.0, 1.0) - 1.0) * PEOPLE_DEPTH
		people_layer.place(f.actor, feet, height, f.facing_angle(), false, depth)
	if f.actor.visible:
		f.actor.set_opacity(f.modulate.a)
		var started := Time.get_ticks_usec() if profile_poses or Perf13.enabled else 0
		var hz := (15.0 if height < 165.0 else 24.0) / maxf(1.0, rate)
		if force_pose:
			f.actor.pose_at(f.clip, f.sample)
		else:
			f.actor.animate(f.clip, f.sample, f.ranged_mix, hz)
		if profile_poses:
			pose_usec += Time.get_ticks_usec() - started
		if Perf13.enabled and f.actor.ranged != null:
			Perf13.end(Perf13.RANGED_POSE, started)
	if long:
		var hit: Vector3 = f.long_model[1]
		if sin(deg_to_rad(f.facing_angle())) > 0.0:
			hit.x = -hit.x
		f.hit_mark = _actor_mark(f, hit)
		f.bar_mark = _actor_mark(f, f.long_model[2])


func _actor_mark(f: Fighter, local: Vector3) -> Vector2:
	var at := people_layer.project(f.actor.to_global(local))
	return (at - world.position) / world.scale


func _track_contact(f: Fighter, weight: float) -> void:
	if f.long_model.is_empty() or not f.unit.alive:
		return
	var u := f.unit
	var target: Fighter = views.get(u.target.id) if u.target != null and u.target.alive else null
	var offset := Vector2.ZERO
	if not u.ranged() and not u.entering and target != null:
		var reach := u.range_m + 0.35 * (u.size + target.unit.size - 2.0)
		var blend := 1.0 - smoothstep(reach, reach + 0.85, LegionSim.dist(u, target.unit))
		var flank := -1.0 if f.flip_h else 1.0
		var guard_x := target.position.x - flank * 48.0 * target.scale.x
		# Подводим морду к строю по X, сохраняя её экранную дорожку.
		offset.x = (guard_x - f.position.x) * blend
	f.contact_adjust = f.contact_adjust.lerp(offset, 1.0 - sqrt(1.0 - weight))


func request_strike(source: Fighter, target: Fighter, action := "") -> void:
	if source.unit.shot != "" or target == null:
		source.attack(action)
		return
	melee_event.emit(source, target)
	if legacy_layout or SIM_POSITIONS:
		source.attack(action)
		melee_pose.emit(source, target)
		return
	source.strike_target = target
	source.strike_action = action
	source.strike_pending = true
	_layout_step = -1


func _fit_foot(f: Fighter, pos: Vector2) -> Vector2:
	var limits := _foot_limits(f)
	return Vector2(clampf(pos.x, limits.x, limits.y), clampf(pos.y, -_trail_depth, _trail_depth))


func _sim_foot(f: Fighter, pos: Vector2) -> Vector2:
	# Только край поля: место бойца задаёт расчёт боя.
	var left := _field_bounds.position.x - f.outline.position.x + 12.0
	var right := _field_bounds.end.x - f.outline.end.x - 12.0
	return Vector2(clampf(pos.x, left, maxf(left, right)), clampf(pos.y, -_trail_depth, _trail_depth))


func _foot_limits(f: Fighter) -> Vector2:
	var left := _field_bounds.position.x - f.outline.position.x + 12.0
	var right := _field_bounds.end.x - f.outline.end.x - 12.0
	var rear_edge := REAR_X - (210.0 if f.wide else 78.0)
	if f.side_dir < 0.0:
		left = maxf(left, -f.front_limit)
		if f.rear:
			right = clampf(-rear_edge, left, right)
		right = clampf(_mounted_line_edge - f.outline.end.x, left, right)
	else:
		right = minf(right, f.front_limit)
		if f.mounted_line and not f.rear:
			left = clampf(_mounted_front_min - f.outline.position.x, left, right)
		if f.rear and not f.rear_mount:
			left = clampf(rear_edge, left, right)
	return Vector2(left, right)


func _plan_layout() -> void:
	var started := Perf13.begin()
	_plan_layout_profiled()
	Perf13.end(Perf13.PLAN, started)


func _plan_layout_profiled() -> void:
	var ally_rear := INF
	var enemy_rear := INF
	var ally_front_width := 0.0
	var mount_edge := _field_bounds.end.x - 12.0
	for i in range(_fighters.size() - 1, -1, -1):
		var f: Fighter = _fighters[i]
		f.approachers.clear()
		f.primary_attacker = null
		f.contact_front = null
		f.visit = 0
		f.contact_blend = 0.0
		if not f.unit.alive:
			continue
		if not f.rear:
			if f.side_dir < 0.0:
				ally_front_width += f.body_width()
			continue
		var u := f.unit
		f.goal = _fit_foot(f, f.layout_point(u.x, u.z))
		if f.rear_mount:
			# Резервируем конным стрелкам место для полного разворота.
			f.goal.x = minf(f.goal.x, mount_edge - f.outline.end.x)
			f.goal = _fit_foot(f, f.goal)
			mount_edge = f.goal.x + f.outline.position.x - 12.0
		var gate := minf(f.goal.x * f.side_dir, f.position.x * f.side_dir) - f.rear_spacing()
		if f.side_dir < 0.0:
			ally_rear = minf(ally_rear, gate)
		else:
			enemy_rear = minf(enemy_rear, gate)
	# Перед конницей должно остаться место для всего пешего строя.
	_mounted_front_min = -ally_rear + ally_front_width + 12.0
	for f in _fighters:
		var previous := f.layout_target
		f.layout_target = null
		if not f.unit.alive or f.rear:
			f.slot = 0
			continue
		f.front_limit = ally_rear if f.side_dir < 0.0 else enemy_rear
		var u := f.unit
		f.goal = _fit_foot(f, f.layout_point(u.x, u.z))
		var target: Fighter = views.get(u.target.id) if u.target != null and u.target.alive else null
		var striking := f.attack_left > 0.0 or (f.sprite != null and f.sprite.animation == &"attack" and f.sprite.is_playing())
		if (target == null or f.long_model.is_empty()) and (f.strike_pending or striking) and is_instance_valid(f.strike_target):
			if f.strike_target.unit.alive or (f.strike_pending and f.can_strike(f.strike_target)):
				target = f.strike_target
		if target == null or u.entering:
			f.slot = 0
			continue
		var reach := u.range_m + 0.35 * (u.size + target.unit.size - 2.0)
		f.contact_blend = 1.0 - smoothstep(reach + 0.32, reach + 2.1, LegionSim.dist(u, target.unit))
		if f.strike_pending or striking:
			f.contact_blend = 1.0
		if f.contact_blend > 0.0:
			f.layout_target = target
			target.approachers.append(f)
		if f.layout_target != previous:
			f.slot = 0
	if SIM_POSITIONS:
		# Места у цели выбирает сам расчёт боя (как в Hustle Castle): рисуем бойцов там, где они в бою.
		for f in _fighters:
			if f.layout_target != null:
				f.slot = 1
		return
	for target in _fighters:
		if not target.approachers.is_empty():
			if target.approachers.size() >= 2:
				target.goal.y = clampf(target.goal.y, -_trail_depth + 35.0, _trail_depth - 35.0)
			_reserve_spots(target)
	for f in _fighters:
		var target := f.layout_target
		if f.holds_chariot():
			f.goal = f.position
			f.visit = 2
		if f.visit != 0 or (target != null and target.holds_chariot()):
			continue
		if target == null or target.layout_target != f or f.slot != 1 or target.slot != 1 or f.unit.id > target.unit.id:
			continue
		# Взаимная пара встречается посередине между исходными местами.
		var center := (f.goal + target.goal) * 0.5
		center.y = clampf(center.y, -_trail_depth * 0.80, _trail_depth * 0.80)
		var gap := f.edge_toward(-f.side_dir) + target.edge_toward(f.side_dir) + minf(f.front_clearance(), target.front_clearance())
		var blend := minf(f.contact_blend, target.contact_blend)
		f.goal = f.goal.lerp(_fit_foot(f, center + Vector2(f.side_dir * gap * 0.5, 0.0)), blend)
		target.goal = target.goal.lerp(_fit_foot(target, center - Vector2(f.side_dir * gap * 0.5, 0.0)), blend)
		f.visit = 2
		target.visit = 2
		if not f.long_model.is_empty() and target.long_model.is_empty():
			target.contact_front = f
		elif not target.long_model.is_empty() and f.long_model.is_empty():
			f.contact_front = target
	for f in _fighters:
		if f.unit.alive:
			_engagement_goal(f)
	_spread_clusters()


func _cluster_root(f: Fighter) -> Fighter:
	var root := f
	while root.cluster_parent != root:
		root = root.cluster_parent
	var node := f
	while node.cluster_parent != root:
		var next := node.cluster_parent
		node.cluster_parent = root
		node = next
	return root


func _spread_clusters() -> void:
	# Схватки (цель и её противники) разводим по глубине тропы, чтобы соседние драки не сливались в кучу.
	var members: Array[Fighter] = []
	for f in _fighters:
		f.cluster_parent = f
		if f.unit.alive and not f.rear and not f.wide:
			members.append(f)
	for f in members:
		var t := f.layout_target
		if t != null and t.unit.alive and not t.rear and not t.wide:
			var a := _cluster_root(f)
			var b := _cluster_root(t)
			if a != b:
				if a.unit.id < b.unit.id:
					b.cluster_parent = a
				else:
					a.cluster_parent = b
	var groups := {}
	for f in members:
		var root := _cluster_root(f)
		if root == f and f.layout_target == null and f.approachers.is_empty():
			continue
		if not groups.has(root):
			groups[root] = []
		(groups[root] as Array).append(f)
	var clusters: Array[Dictionary] = []
	for root: Fighter in groups:
		var list: Array = groups[root]
		if list.size() < 2:
			continue
		var left := INF
		var right := -INF
		var y := 0.0
		for f: Fighter in list:
			left = minf(left, f.goal.x - f.body_half * 1.6)
			right = maxf(right, f.goal.x + f.body_half * 1.6)
			y += f.goal.y
		y /= list.size()
		clusters.append({"root": root, "list": list, "left": left, "right": right, "y": y, "lane": INF})
	if clusters.size() < 2:
		_cluster_lanes.clear()
		return
	var step := minf(_trail_depth * 0.62, 74.0)
	var lanes: Array[float] = [-step, 0.0, step, -step * 0.5, step * 0.5]
	clusters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	var seen := {}
	for c: Dictionary in clusters:
		var taken: Array[float] = []
		for other: Dictionary in clusters:
			if other == c or float(other["lane"]) == INF:
				continue
			if float(other["left"]) < float(c["right"]) and float(c["left"]) < float(other["right"]):
				taken.append(float(other["lane"]))
		var root: Fighter = c["root"]
		var key := root.unit.id
		seen[key] = true
		if taken.is_empty():
			# Одиночная схватка остаётся на своей глубине, лишь не уходит за край тропы.
			c["lane"] = clampf(float(c["y"]), -step, step)
			_cluster_lanes[key] = c["lane"]
			continue
		var best := INF
		var best_cost := INF
		for lane in lanes:
			var clash := false
			for used in taken:
				if absf(used - lane) < step * 0.45:
					clash = true
			if clash:
				continue
			var cost := absf(lane - float(c["y"]))
			if _cluster_lanes.has(key) and absf(float(_cluster_lanes[key]) - lane) < 1.0:
				cost -= step * 0.8
			if cost < best_cost:
				best_cost = cost
				best = lane
		if best == INF:
			best = clampf(float(c["y"]), -step, step)
		c["lane"] = best
		_cluster_lanes[key] = best
	for key in _cluster_lanes.keys():
		if not seen.has(key):
			_cluster_lanes.erase(key)
	for c: Dictionary in clusters:
		var dy := float(c["lane"]) - float(c["y"])
		if absf(dy) < 0.5:
			continue
		for f: Fighter in c["list"]:
			f.goal = _fit_foot(f, f.goal + Vector2(0.0, dy))


func _reserve_spots(target: Fighter) -> void:
	var at := target.goal if target.unit.alive else target.position
	var first: Fighter
	var best := INF
	for f in target.approachers:
		var cost := f.position.distance_to(_spot(f, target, at, 1))
		if f.slot == 1:
			cost -= 170.0
		if target.layout_target == f:
			cost -= 240.0
		if f.unit.boss and not f.long_model.is_empty():
			cost -= 480.0
		if cost < best:
			first = f
			best = cost
	first.slot = 1
	target.primary_attacker = first
	if not first.long_model.is_empty() and target.long_model.is_empty():
		target.contact_front = first
	var used := 0
	var first_flank: Fighter
	var second_flank: Fighter
	for count in mini(2, target.approachers.size() - 1):
		var selected: Fighter
		var spot := 0
		best = INF
		for f in target.approachers:
			if f == first or f == first_flank:
				continue
			for slot_index in range(2, 4):
				if slot_index == used:
					continue
				var p := _spot(f, target, at, slot_index)
				var cost := f.position.distance_to(p)
				# Занятое место держим: перестановки у цели выглядят как беготня.
				if f.slot == slot_index:
					cost -= 190.0
				if cost < best:
					best = cost
					selected = f
					spot = slot_index
		selected.slot = spot
		if count == 0:
			first_flank = selected
			used = spot
		else:
			second_flank = selected
	for f in target.approachers:
		if f != first and f != first_flank and f != second_flank:
			f.slot = 4


func _spot(f: Fighter, target: Fighter, at: Vector2, slot: int) -> Vector2:
	var dir := f.side_dir
	if f.unit.side == "enemy" and f.unit.enter_dir > 0.0:
		dir = -1.0
	var our_long := f.wide
	var their_long := target.wide
	# У длинной модели переднее место всегда у морды.
	if not target.long_model.is_empty() and not target.mounted_line and not our_long:
		dir = -1.0 if target.flip_h else 1.0
	var depth := at.y
	var source_edge := f.edge_toward(-dir) if our_long and f.long_model.is_empty() else f.muzzle
	var space := f.front_clearance()
	if their_long and not our_long:
		space = 8.0
	if slot == 2 or slot == 3:
		# Второй и третий нападающие встают наискосок со своей стороны, не за спиной цели.
		var lane := -1.0 if slot == 2 else 1.0
		if lane * at.y > _trail_depth - 35.0:
			lane = -lane
		depth += lane * minf(50.0, f.strike_distance * 0.72)
		if their_long or our_long:
			space = f.strike_distance * (0.48 if their_long else 0.10)
		else:
			# Дальний по глубине чуть отступает, ближний чуть подходит: группа не встаёт столбиком.
			space = f.front_clearance() * (0.55 if depth < at.y else 0.25) + (f.body_half * 0.55 if depth < at.y else 0.0)
	elif slot >= 4:
		space += maxf(64.0, f.body_width())
		depth = f.goal.y
	var target_edge := target.edge_toward(dir)
	if not target.long_model.is_empty() and not target.rear_mount and not our_long:
		target_edge = target.muzzle
	var distance := source_edge + target_edge + space
	var x := at.x + dir * distance
	if x * f.side_dir > f.front_limit and not their_long:
		x = f.front_limit * f.side_dir
	return _fit_foot(f, Vector2(x, depth))


func _engagement_goal(f: Fighter) -> void:
	var started := Perf13.begin()
	_engagement_goal_profiled(f)
	Perf13.end(Perf13.GOAL, started)


func _engagement_goal_profiled(f: Fighter) -> void:
	if f.visit != 0:
		return
	f.visit = 1
	var target := f.layout_target
	if target != null and target.visit != 1:
		_engagement_goal(target)
		var at := target.goal if target.unit.alive else target.position
		f.goal = f.goal.lerp(_spot(f, target, at, f.slot), f.contact_blend)
	f.visit = 2


func _layout(weight: float) -> void:
	_wide_fighters.clear()
	if SIM_POSITIONS:
		for f in _fighters:
			if f.unit.alive:
				f.spawn_pending = false
				f.position = _sim_foot(f, f.layout_point(f.unit.x, f.unit.z))
		return
	for f in _fighters:
		if not f.unit.alive:
			continue
		var goal := f.goal
		f.passing = false
		var front := f.contact_front
		if front != null and not f.holds_chariot():
			# Линия держится по спроецированной морде ведущей повозки.
			var dir := -1.0 if front.flip_h else 1.0
			var x := front.position.x + dir * (front.muzzle + f.edge_toward(-dir) + front.front_clearance())
			goal.x = lerpf(goal.x, x, front.contact_blend)
			if f.layout_target == front:
				goal.y = lerpf(goal.y, front.position.y, front.contact_blend * 0.65)
			goal = _fit_foot(f, goal)
		if f.spawn_pending:
			f.spawn_pending = false
			f.position = _fit_foot(f, f.position)
		var path := goal if SIM_POSITIONS or f.wide or f.rear else _around(f, goal)
		f.next_foot = _fit_foot(f, f.position.lerp(path, minf(1.0, weight * 2.0) if f.passing else weight))
		if f.wide:
			_wide_fighters.append(f)
	for f in _fighters:
		if f.unit.alive:
			f.position = f.next_foot
	_space_wide()
	_fit_mounted_line()
	for f in _fighters:
		var front := f.contact_front
		if not f.unit.alive or front == null or not front.unit.alive or front.contact_blend < 0.95 or f.holds_chariot():
			continue
		var dir := -1.0 if front.flip_h else 1.0
		var contact := front.position.x + dir * (front.muzzle + f.edge_toward(-dir) + front.front_clearance())
		var pull := minf(1.0, weight * 2.5)
		f.position = _fit_foot(f, Vector2(lerpf(f.position.x, contact, pull), f.position.y))
	_separate()


func _use_layout_positions() -> void:
	for f in _fighters:
		if f.unit.alive and f.display_ready:
			f.display_pos = f.position
			f.position = f.layout_pos


func _keep_layout_positions() -> void:
	for f in _fighters:
		if not f.unit.alive:
			continue
		f.layout_pos = f.position
		if f.display_ready:
			f.position = f.display_pos
		else:
			f.display_ready = true
			f.display_vel = Vector2.ZERO


func _advance_display(gdt: float) -> void:
	# Экранная фигура догоняет расчётное место шагом: без рывков и без мгновенных разворотов.
	for f in _fighters:
		if not f.unit.alive or not f.display_ready:
			f.travel = Vector2.ZERO
			continue
		var delta := f.layout_pos - f.position
		var distance := delta.length()
		if gdt <= 0.0:
			f.travel = Vector2.ZERO
			continue
		var cap := f.walk_cap()
		if distance < 0.6 and f.display_vel.length_squared() < 400.0:
			f.position = f.layout_pos
			f.display_vel = Vector2.ZERO
			f.travel = Vector2.ZERO
			continue
		var desired := delta * DISPLAY_GAIN
		if desired.length() > cap:
			desired = desired * (cap / desired.length())
		f.display_vel = f.display_vel.move_toward(desired, cap * DISPLAY_ACCEL * gdt)
		var step := f.display_vel * gdt
		if step.length() > distance:
			step = delta
			f.display_vel = delta / gdt
		f.position += step
		f.travel = step


func _layout_finish() -> void:
	for f in _fighters:
		if not f.unit.alive:
			continue
		var u := f.unit
		var aim := f.aim_target if f.aim_target != null and f.aim_target.alive else u.target
		var target: Fighter = views.get(aim.id) if aim != null and aim.alive else f.layout_target
		var follow_strike := (f.layout_target == null or f.long_model.is_empty()) and (f.strike_pending or f.attack_left > 0.0)
		if follow_strike and is_instance_valid(f.strike_target):
			if f.strike_target.unit.alive or f.can_strike(f.strike_target):
				target = f.strike_target
		if target != null and not u.entering:
			f.aim_at(target)
		else:
			f.aim_depth = 0.0
			f.face(u.enter_dir < 0.0 if u.entering else f.side_dir > 0.0)
		f.update_outline()
	for f in _fighters:
		if not f.unit.alive or f.rear:
			continue
		var striking := f.attack_left > 0.0 or (f.sprite != null and f.sprite.animation == &"attack" and f.sprite.is_playing())
		if striking and (not is_instance_valid(f.strike_target) or not f.can_strike(f.strike_target)):
			f.attack_left = 0.0
			if f.sprite == null:
				f.clip = f.idle_clip
			else:
				f.sprite.play(&"idle")
		if f.strike_pending:
			if not is_instance_valid(f.strike_target) or (not f.strike_target.unit.alive and f.layout_target != f.strike_target):
				f.strike_pending = false
			elif f.slot > 0 and f.slot < 4 and f.can_strike(f.strike_target):
				f.strike_pending = false
				f.attack(f.strike_action)
				melee_pose.emit(f, f.strike_target)


func _around(f: Fighter, goal: Vector2) -> Vector2:
	var from := f.position
	if absf(goal.x - from.x) < 32.0:
		f.bypass = null
		return goal
	var direction := signf(goal.x - from.x)
	var nearest := absf(goal.x - from.x)
	var obstacle: Fighter
	var passage := Rect2()
	for other in _fighters:
		if other == f or not other.unit.alive:
			continue
		var x := other.position.x
		var left := x + other.outline.position.x - f.outline.end.x * 0.63 - 6.0
		var right := x + other.outline.end.x - f.outline.position.x * 0.63 + 6.0
		# Обходим препятствие, если путь ведёт на другую сторону.
		var approach := left if direction > 0.0 else right
		var exit_ := right if direction > 0.0 else left
		if (x - from.x) * direction <= 0.0 or (goal.x - x) * direction < 25.0:
			continue
		var at_x := clampf(approach, minf(from.x, goal.x), maxf(from.x, goal.x))
		var dist := absf(at_x - from.x)
		if dist >= nearest:
			continue
		var at_y := lerpf(from.y, goal.y, dist / absf(goal.x - from.x))
		var radius := 40.0 if not other.wide else 47.0
		if absf(at_y - other.position.y) >= radius and f.bypass != other:
			continue
		var top := other.position.y - radius
		var bottom := other.position.y + radius
		if top < -_trail_depth and bottom > _trail_depth:
			continue
		nearest = dist
		obstacle = other
		passage = Rect2(approach, top, exit_ - approach, bottom - top)
	if obstacle == null:
		f.bypass = null
		return goal
	if f.bypass != obstacle:
		f.bypass = obstacle
		var bottom := passage.end.y
		var top := passage.position.y
		f.bypass_lower = top < -_trail_depth or (bottom <= _trail_depth and
			absf(from.y - bottom) + absf(goal.y - bottom) < absf(from.y - top) + absf(goal.y - top))
	var lane := passage.end.y + 3.0 if f.bypass_lower else passage.position.y - 3.0
	var ahead := maxf(0.0, (passage.position.x - from.x) * direction)
	var x := passage.end.x + direction * 6.0
	f.passing = not obstacle.wide and absf(from.y - lane) <= 7.0
	if absf(from.y - lane) > 7.0:
		x = from.x + direction * ahead
	return _fit_foot(f, Vector2(x, lane))


func _wide_order(f: Fighter) -> float:
	# Колесничий, который ведёт атаку, остаётся впереди второй повозки.
	if f.unit.key == "charioteer":
		return _field_bounds.position.x if f.side_dir > 0.0 else _field_bounds.end.x
	if f.rear_mount:
		return _field_bounds.end.x + _field_bounds.size.x * 2.0 + float(f.unit.id)
	if f.rear:
		return f.position.x + _field_bounds.size.x * f.side_dir
	return f.position.x


func _space_wide() -> void:
	_wide_fighters.sort_custom(func(a: Fighter, b: Fighter) -> bool: return _wide_order(a) < _wide_order(b))
	# Сначала уступает задний корпус. У края поля освобождаем место спереди.
	for i in range(1, _wide_fighters.size()):
		var a := _wide_fighters[i - 1]
		var b := _wide_fighters[i]
		var gap := _wide_gap(a, b)
		b.position = _fit_foot(b, Vector2(maxf(b.position.x, a.position.x + gap), b.position.y))
	for i in range(_wide_fighters.size() - 2, -1, -1):
		var a := _wide_fighters[i]
		var b := _wide_fighters[i + 1]
		var gap := _wide_gap(a, b)
		a.position = _fit_foot(a, Vector2(minf(a.position.x, b.position.x - gap), a.position.y))


func _wide_gap(a: Fighter, b: Fighter) -> float:
	var min_width := minf(a.body_width(), b.body_width())
	var edges := a.outline.end.x - b.outline.position.x
	if a.rear_mount or b.rear_mount:
		return edges + 12.0
	var overlap := minf(a.outline.size.x, b.outline.size.x) * (0.42 if _wide_fighters.size() > 2 else 0.25)
	return clampf(edges - overlap, min_width * 0.53, min_width * 0.92)


func _fit_mounted_line() -> void:
	_mounted_line_edge = INF
	for f in _wide_fighters:
		if f.mounted_line:
			var nose := minf(f.outline.position.x, -f.outline.end.x)
			_mounted_line_edge = minf(_mounted_line_edge, f.position.x + nose - 12.0)
	if _mounted_line_edge < INF:
		for f in _fighters:
			if f.unit.alive and f.side_dir < 0.0:
				f.position = _fit_foot(f, f.position)


var _separation_neighbors := PackedInt32Array()
var _separation_ends := PackedInt32Array()
var _separation_checked := PackedInt32Array()


func _separate() -> void:
	var started := Perf13.begin()
	_separate_profiled()
	Perf13.end(Perf13.SEPARATE, started)


func _separate_profiled() -> void:
	# В первых шести проходах меняется только X. Пары с разных рядов отсекаем один раз.
	var count := _fighters.size()
	var capacity := count * (count - 1) / 2
	if _separation_neighbors.size() < capacity:
		_separation_neighbors.resize(capacity)
		_separation_checked.resize(capacity)
		_separation_ends.resize(count)
	var pairs := 0
	for i in count:
		var a: Fighter = _fighters[i]
		if a.unit.alive:
			a.separation_position = a.position
			a.separation_generation = 0
			a.separation_priority = a.guard_priority()
			a.separation_limits = _foot_limits(a)
			for j in i:
				var b: Fighter = _fighters[j]
				if not b.unit.alive or (a.wide and b.wide):
					continue
				var dy := (a.separation_position - b.separation_position).y
				var feet := minf(a.body_half, b.body_half) * 1.1
				if absf(dy) >= feet and (dy + a.outline.end.y <= b.outline.position.y or dy + a.outline.position.y >= b.outline.end.y):
					continue
				_separation_neighbors[pairs] = j
				_separation_checked[pairs] = -1
				pairs += 1
		if count >= 2:
			_separation_ends[i] = pairs
	if pairs == 0:
		return
	var moved := false
	for pass_index in 6:
		moved = false
		var pair := 0
		for i in count:
			var a: Fighter = _fighters[i]
			var limit: int = _separation_ends[i]
			var a_box := a.outline
			var a_wide := a.wide
			while pair < limit:
				var b: Fighter = _fighters[_separation_neighbors[pair]]
				var pair_index := pair
				pair += 1
				# У пары без пересечения нет новой работы, пока обе позиции прежние.
				var epoch := a.separation_generation + b.separation_generation
				if _separation_checked[pair_index] == epoch:
					continue
				var d := a.separation_position - b.separation_position
				var b_box := b.outline
				var b_wide := b.wide
				var same_side := a.side_dir == b.side_dir
				var feet := minf(a.body_half, b.body_half) * 1.1
				var mount_pair := a.rear_mount or b.rear_mount
				var clearance := 12.0 if mount_pair else 0.0
				if absf(d.x) >= maxf(feet, maxf(b.end_x - a_box.position.x, a.end_x - b_box.position.x) + clearance):
					_separation_checked[pair_index] = epoch
					continue
				var dx := sqrt(maxf(0.0, feet * feet - d.y * d.y)) - absf(d.x)
				var side := signf(d.x) if absf(d.x) > 0.01 else a.side_dir
				var passing := (a.passing and a.bypass == b or b.passing and b.bypass == a) and absf(d.y) >= 35.0
				if not passing:
					var height := minf(d.y + a_box.end.y, b_box.end.y) - maxf(d.y + a_box.position.y, b_box.position.y)
					if height > 0.0:
						var min_area := minf(a.outline_area, b.outline_area)
						var tolerance := 0.13 if same_side else (0.08 if a_wide or b_wide else 0.20)
						var permitted := -clearance if mount_pair else min_area * tolerance / height
						if permitted < minf(a_box.size.x, b_box.size.x):
							var facing := d.x + a.center_x - b.center_x
							# У повозки порядок берём по центру проекции.
							var box_side := signf(facing) if absf(facing) > 0.01 else side
							if a.contact_front == b:
								box_side = -1.0 if b.flip_h else 1.0
							elif b.contact_front == a:
								box_side = 1.0 if a.flip_h else -1.0
							var edge := b_box.end.x - a_box.position.x if box_side > 0.0 else a_box.end.x - b_box.position.x
							var push := edge - d.x * box_side - permitted
							if push > dx:
								dx = push
								side = box_side
				if dx <= 0.34:
					_separation_checked[pair_index] = epoch
					continue
				var share := 0.5
				var a_priority := a.separation_priority
				var b_priority := b.separation_priority
				if a_wide != b_wide:
					share = 0.0 if a_wide else 1.0
				elif a_priority != b_priority:
					share = 0.0 if a_priority > b_priority else 1.0
				elif a.rear != b.rear:
					share = 0.15 if a.rear else 0.85
				var old_a := a.separation_position.x
				var old_b := b.separation_position.x
				a.separation_position = a.separation_bound(a.separation_position + Vector2(dx * side * share, 0.0))
				var remaining := dx - (a.separation_position.x - old_a) * side
				if not b_wide and (a_wide or b_priority <= a_priority):
					b.separation_position = b.separation_bound(b.separation_position - Vector2(side * remaining, 0.0))
				remaining -= (old_b - b.separation_position.x) * side
				if remaining > 0.34 and not a_wide and (b_wide or a_priority <= b_priority):
					a.separation_position = a.separation_bound(a.separation_position + Vector2(side * remaining, 0.0))
				if a.separation_position.x != old_a:
					a.separation_generation += 1
				if b.separation_position.x != old_b:
					b.separation_generation += 1
				moved = true
		if not moved:
			break
	for f in _fighters:
		if f.unit.alive and f.separation_generation != 0:
			f.position = f.separation_position
	if moved:
		# Последний проход раздвигает по глубине, порядок пар сохраняется.
		for i in count:
			var a: Fighter = _fighters[i]
			if not a.unit.alive or a.wide:
				continue
			for j in i:
				var b: Fighter = _fighters[j]
				if not b.unit.alive or b.wide or a.side_dir != b.side_dir:
					continue
				var d := a.position - b.position
				var feet := minf(a.body_half, b.body_half) * 1.1
				if d.length_squared() < (feet * 0.60) ** 2:
					_step_aside(a, b, d, feet)


func _step_aside(a: Fighter, b: Fighter, d: Vector2, feet: float) -> void:
	# Когда по X места не осталось, освобождаем проход в глубину.
	var gap := sqrt(maxf(0.0, feet * feet - d.x * d.x)) - absf(d.y)
	var direction := -1.0 if d.y < 0.0 else 1.0
	var start := a.position.y
	var fixed_a := a.holds_chariot()
	var fixed_b := b.holds_chariot()
	if not fixed_a:
		var share := 1.0 if fixed_b else 0.5
		a.position.y = clampf(start + direction * gap * share, -_trail_depth, _trail_depth)
	gap -= (a.position.y - start) * direction
	if not fixed_b:
		start = b.position.y
		b.position.y = clampf(start - direction * gap, -_trail_depth, _trail_depth)
		gap -= (start - b.position.y) * direction
	if not fixed_a and gap > 0.0:
		a.position.y = clampf(a.position.y + direction * gap, -_trail_depth, _trail_depth)


func burst(kind: String, where: Vector2, radius := 1.0, tint := Color.WHITE) -> void:
	if _bursts.size() >= 48:
		_bursts.pop_front().queue_free()
	var f := Burst.new()
	f.sprite_frames = _effect_frames(kind)
	f.animation = &"effect"
	f.position = where
	f.scale = Vector2.ONE * radius * (1.0 if legacy_layout else FIGURE_SCALE)
	f.modulate = tint
	effects.add_child(f)
	_bursts.append(f)


func ring(where: Vector2, radius: float, color: Color, time := 0.7) -> void:
	ground.marks.append({"pos": where, "radius": radius, "color": color, "t": time, "lifetime": time})


func lane(z: float, color: Color, time: float, width := 14.0) -> void:
	ground.lanes.append({"z": z, "color": color, "t": time, "lifetime": time, "width": width})


func _projectile(kind: String) -> Node2D:
	if kind in ["arrow", "bolt"]:
		var arrow := AnimatedSprite2D.new()
		arrow.sprite_frames = _effect_frames("fx_arrow")
		arrow.animation = &"effect"
		arrow.scale = Vector2.ONE * (0.72 if kind == "bolt" else 0.56)
		return arrow
	var stone := Sprite2D.new()
	stone.texture = _stone
	stone.scale = Vector2.ONE * (18.0 if kind == "sling" else 40.0) / _stone.get_width()
	return stone


func shoot(s: LegionSim.Shot) -> void:
	var sprite := _projectile(s.kind)
	sprite.name = "BattleProjectile"
	if not legacy_layout:
		sprite.scale *= FIGURE_SCALE
	effects.add_child(sprite)
	shots[s] = sprite
	var source: Fighter = views.get(s.from.id) if s.from != null else null
	if not legacy_layout and source != null:
		var target: Fighter = views.get(s.target.id) if s.target != null else null
		if target != null:
			source.aim_at(target)
		sprite.set_meta("origin", source.chest())
	if source != null and source.actor != null and source.actor.ranged != null:
		var launch := _release(source)
		if not legacy_layout:
			source.aim_target = s.target
		sprite.set_meta("launch", launch)
		sprite.set_meta("release_frame", Engine.get_process_frames())
		if source.boss_model != null:
			sprite.set_meta("boss_launch", launch)
	elif source != null and source.boss_model != null and source.unit.key == "cyclops":
		source.actor.pose_at(source.attack_clip, 0.0)
		_place_actor(source)
		var launch := people_layer.project(source.boss_model.launch_point())
		sprite.set_meta("boss_launch", (launch - world.position) / world.scale)
	_place_shot(s, sprite, 0.0)


func cast(source: Fighter, target: Fighter = null) -> void:
	if not legacy_layout and target != null:
		source.aim_at(target)
	if source.actor != null and source.actor.ranged != null and source.actor.ranged.mode == "cast":
		_release(source)
		if not legacy_layout and target != null:
			source.aim_target = target.unit
	else:
		source.attack()


func _release(source: Fighter) -> Vector2:
	source.release_ranged()
	_place_actor(source, 1.0, true)
	people_layer.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not source.actor.visible:
		source.actor.pose_at(source.clip, source.sample)
	var ranged := source.actor.ranged
	var launch := people_layer.project(ranged.anchor.to_global(ranged.launch))
	var at := (launch - world.position) / world.scale
	if ranged.mode == "cast":
		burst("fx_heal", at, 0.70)
	return at


func volley(origin: Vector2, target: Vector2, tint: Color) -> void:
	var f := Flight.new()
	f.origin = origin
	f.target = target
	f.sprite_frames = _effect_frames("fx_arrow")
	f.animation = &"effect"
	f.scale = Vector2.ONE * 0.78
	f.position = origin
	f.rotation = (target - origin).angle()
	f.modulate = tint
	effects.add_child(f)
	_flights.append(f)


func _place_shot(s: LegionSim.Shot, sprite: Node2D, k: float) -> void:
	var source: Fighter = views.get(s.from.id) if s.from != null else null
	var target: Fighter = views.get(s.target.id) if s.target != null else null
	var a := (source.layout_point(s.x0, s.z0) if source != null else point(s.x0, s.z0)) - Vector2(0, 138.0)
	if sprite.has_meta("launch"):
		a = sprite.get_meta("launch")
	elif sprite.has_meta("boss_launch"):
		a = sprite.get_meta("boss_launch")
	elif sprite.has_meta("origin"):
		a = sprite.get_meta("origin")
	var b := (target.layout_point(s.x1, s.z1) if target != null else point(s.x1, s.z1)) - Vector2(0, 100.0)
	if target != null and (not legacy_layout or not target.long_model.is_empty()):
		b = target.chest()
	var arc := 32.0 + absf(b.x - a.x) * 0.08
	if s.kind in ["stone", "boulder"]:
		arc *= 1.8
	elif s.kind == "bolt":
		arc *= 0.3
	sprite.position = a.lerp(b, k) - Vector2(0, sin(k * PI) * arc)
	if sprite is AnimatedSprite2D:
		sprite.rotation = (b - a - Vector2(0, cos(k * PI) * PI * arc)).angle()
		(sprite as AnimatedSprite2D).frame = mini(3, int(k * 4.0))
	else:
		sprite.rotation = k * 9.0


func tick(sim: LegionSim, gdt: float, dt: float, acc: float, fighting: bool) -> void:
	var weight := 1.0 - exp(-dt * 16.0) if gdt > 0.0 else 0.0
	var rate := gdt / dt if dt > 0.0 else 0.0
	_people_time += dt
	var interval := PEOPLE_FRAME if legacy_layout else 1.0 / 80.0
	var refresh_people := _people_time >= interval
	if refresh_people:
		_people_time = fposmod(_people_time, interval)
		people_layer.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not legacy_layout and weight > 0.0:
		_layout_time += dt
		_layout_sim_time += gdt
		var laid_out := false
		if _layout_time >= 1.0 / 60.0:
			_use_layout_positions()
			if _layout_step != sim.steps:
				_plan_layout()
				_layout_step = sim.steps
			_layout(1.0 - exp(-_layout_sim_time * 14.0))
			_keep_layout_positions()
			_layout_time = fposmod(_layout_time, 1.0 / 60.0)
			_layout_sim_time = 0.0
			laid_out = true
		_advance_display(gdt)
		if laid_out:
			_layout_finish()
	var started := Time.get_ticks_usec() if profile_poses else 0
	for id in views:
		var f: Fighter = views[id]
		var was_winding := f.ranged_winding
		var death_before := f.death
		f.tick(gdt, rate, weight, fighting, sim.t, f.heal_due(sim, fighting))
		if f.ranged_winding and not was_winding:
			match f.actor.ranged.mode:
				"bow":
					field_sound.emit("bow_draw", sound_pan(f.position))
				"sling":
					field_sound.emit("sling_whirl", sound_pan(f.position))
		if not f.unit.alive:
			var ground_at := f.death_ground()
			if death_before < ground_at and f.death >= ground_at:
				field_sound.emit("fall", sound_pan(f.position))
	if started != 0:
		windup_usec += Time.get_ticks_usec() - started
	for id in views:
		var f: Fighter = views[id]
		if legacy_layout:
			_track_contact(f, weight)
		if (legacy_layout or refresh_people) and f.release_frame != Engine.get_process_frames():
			_place_actor(f, rate)
		if f.unit.alive:
			f.status(sim.t, fighting)
		elif f.modulate.a <= 0.0:
			f.queue_free()
			_dead_ids.append(id)
	for id in _dead_ids:
		_fighters.erase(views[id])
		views.erase(id)
		_layout_step = -1
	_dead_ids.clear()
	var frame := Engine.get_process_frames()
	for s: LegionSim.Shot in shots:
		var sprite: Node2D = shots[s]
		if s.done or not sim.result.is_empty():
			if s.done:
				var event := "boulder" if s.kind in ["stone", "boulder", "bolt"] else ("stone_hit" if s.kind == "sling" else "arrow_hit")
				var target: Fighter = views.get(s.target.id) if s.target != null else null
				var impact := target.position if target != null and s.kind in ["arrow", "sling"] else point(s.x1, s.z1)
				field_sound.emit(event, sound_pan(impact))
			sprite.queue_free()
			_done_shots.append(s)
		elif int(sprite.get_meta("release_frame", -1)) != frame:
			_place_shot(s, sprite, clampf((s.t + acc) / s.dur, 0.0, 1.0))
	for s: LegionSim.Shot in _done_shots:
		shots.erase(s)
	_done_shots.clear()
	for i in range(_bursts.size() - 1, -1, -1):
		var f := _bursts[i]
		f.age += gdt
		if f.age >= 0.34:
			f.queue_free()
			_bursts.remove_at(i)
		else:
			f.frame = mini(3, int(f.age * 12.0))
	for i in range(_flights.size() - 1, -1, -1):
		var f := _flights[i]
		f.age += gdt
		var k := f.age / 0.42
		if k >= 1.0:
			f.queue_free()
			_flights.remove_at(i)
		else:
			f.frame = mini(3, int(k * 4.0))
			f.position = f.origin.lerp(f.target, k) - Vector2(0, sin(k * PI) * 70.0)
	ground.tick(gdt)


func clear_visible() -> void:
	people_layer.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var started := Perf14.begin()
	var deadline := Time.get_ticks_usec() + 3500
	var count := 0
	for root: Node2D in [units, effects]:
		for child: Node in root.get_children():
			root.remove_child(child)
			child.queue_free()
			count += 1
			if count >= 4 or Time.get_ticks_usec() >= deadline:
				count = 0
				Perf14.end(Perf14.BATTLE_CLOSE, started)
				await get_tree().process_frame
				started = Perf14.begin()
				deadline = Time.get_ticks_usec() + 3500
	Perf14.end(Perf14.BATTLE_CLOSE, started)


func clear() -> void:
	for root: Node2D in [units, effects]:
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()
	views.clear()
	_fighters.clear()
	_wide_fighters.clear()
	_mounted_line_edge = INF
	_mounted_front_min = -INF
	_layout_step = -1
	_layout_time = 0.0
	_layout_sim_time = 0.0
	_enemy_variants.clear()
	shots.clear()
	_bursts.clear()
	_flights.clear()
	ground.marks.clear()
	ground.lanes.clear()
	ground.crowds.clear()
	ground.queue_redraw()


class Fighter extends Node2D:
	var unit: LegionSim.Unit
	var view: LegionBattleView
	var side_dir := 1.0
	var rear := false
	var rear_mount := false
	var mounted_line := false
	var turn_radius := 0.0
	var goal := Vector2.ZERO
	var travel := Vector2.ZERO
	# Расстановка считает layout_pos, а на экране боец идёт к нему шагом.
	var layout_pos := Vector2.ZERO
	var display_pos := Vector2.ZERO
	var display_vel := Vector2.ZERO
	var display_ready := false
	var cluster_parent: Fighter
	var drawn_foot := Vector2.ZERO
	var spawn_pending := true
	var body_half := 25.0
	var muzzle := 25.0
	var rump := 25.0
	var beam := 50.0
	var front_limit := INF
	var strike_distance := 55.0
	var aim_depth := 0.0
	var approachers: Array[Fighter] = []
	var primary_attacker: Fighter
	var outline := Rect2()
	var hull_points := PackedVector3Array()
	var hull_angle := INF
	var _outline_scale := -1.0
	var _outline_pose: StringName
	var hud_anchor := Vector2.ZERO
	var outline_area := 0.0
	var center_x := 0.0
	var end_x := 0.0
	var separation_position := Vector2.ZERO
	var separation_limits := Vector2.ZERO
	var separation_priority := 0
	var separation_generation := 0
	var bypass: Fighter
	var bypass_lower := false
	var passing := false
	var next_foot := Vector2.ZERO
	var layout_target: Fighter
	var contact_front: Fighter
	var strike_target: Fighter
	var strike_pending := false
	var strike_action := ""
	var slot := 0
	var visit := 0
	var contact_blend := 0.0
	var sheet := ""
	var silhouette := Vector2.ZERO
	var health := 1.0
	var flash := 0.0
	var death := 0.0
	var status_color := Color.TRANSPARENT
	var sprite: AnimatedSprite2D
	var actor: Actor
	var flip_h := false
	var lane_z := 0.0
	var yaw := 56.0
	var actor_height := 0.0
	var wide := false
	var wide_lane := 0
	var in_wide_wave := false
	var boss_model: Boss
	var long_model: Array = []
	var contact_adjust := Vector2.ZERO
	var hit_mark := Vector2.ZERO
	var bar_mark := Vector2.ZERO
	var shoot_turn := 0.0
	var ranged_mix := 1.0
	var ranged_winding := false
	var aim_target: LegionSim.Unit
	var release_frame := -1
	var release_time := 0.0
	var heal_step := -1
	var heal_ready := false
	var idle_clip := "Idle"
	var walk_clip := "Walk"
	var attack_clip := "Sword_Attack"
	var hit_clip := ""
	var death_clip := ""
	var clip := "Idle"
	var sample := 0.0
	var attack_left := 0.0
	var hit_left := 0.0

	func _exit_tree() -> void:
		if is_instance_valid(actor):
			actor.hide()
			actor.queue_free()

	func face(left: bool) -> void:
		flip_h = left
		if sprite != null:
			sprite.flip_h = left
			sprite.offset = Vector2((silhouette.x - 128.0) * (1.0 if left else -1.0), 128.0 - LegionBattleView.BASELINE)

	func measure_body() -> void:
		side_dir = -1.0 if unit.side == "ally" else 1.0
		rear = unit.ranged() or unit.heal_pow > 0.0
		rear_mount = rear and wide and not long_model.is_empty()
		mounted_line = rear_mount or unit.key == "cataphract"
		var torso := 0.63
		var breadth := torso
		var front_edge := 0.0
		if actor != null and (wide or boss_model != null):
			var bounds := AABB()
			hull_points.clear()
			for part: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
				if part.visible and part.mesh != null:
					var local := actor.global_transform.affine_inverse() * part.global_transform
					var mesh_bounds := part.mesh.get_aabb()
					var hull := local * mesh_bounds
					bounds = hull if not bounds.has_volume() else bounds.merge(hull)
					for corner in 8:
						hull_points.append(local * mesh_bounds.get_endpoint(corner))
			var angle := deg_to_rad(yaw)
			breadth = maxf(breadth, bounds.size.x)
			torso = maxf(torso, bounds.size.x * absf(cos(angle)) + bounds.size.z * absf(sin(angle)))
			if not long_model.is_empty():
				var end: Vector2 = long_model[0]
				front_edge = end.x * cos(angle) + end.y * sin(angle)
				torso = maxf(torso, front_edge * 1.38)
		var units := model_height() / 1.79
		turn_radius = 0.0
		if rear_mount:
			for corner in hull_points:
				turn_radius = maxf(turn_radius, Vector2(corner.x, corner.z).length())
			turn_radius *= units / cos(deg_to_rad(PEOPLE_TILT))
		body_half = torso * units * 0.5
		beam = breadth * units
		muzzle = front_edge * units / cos(deg_to_rad(PEOPLE_TILT)) if front_edge > 0.0 else body_half
		rump = maxf(body_half * 0.5, body_width() - muzzle)
		var gear: Array = Enemy.HUMANS.get(unit.key, [])
		var weapon := String(gear[1]) if not gear.is_empty() else ""
		strike_distance = clampf(model_height() * 0.36, 47.0, 72.0)
		if unit.key == "spearman" or weapon in ["spear", "pike", "falx", "axe", "staff"]:
			strike_distance += 18.0

		hull_angle = INF
		update_outline()

	func update_outline() -> void:
		var started := Perf13.begin()
		update_outline_profiled()
		Perf13.end(Perf13.OUTLINE, started)


	func update_outline_profiled() -> void:
		var scaled := _outline_scale != scale.y
		_outline_scale = scale.y
		if hull_points.is_empty():
			var pose := sprite.animation if sheet == "bear" and sprite != null else &""
			if hull_angle == INF or scaled or pose != _outline_pose:
				var height := body_height()
				outline = Rect2(-body_half, -height, body_width(), height)
				hull_angle = 0.0
				_outline_pose = pose
				_cache_outline()
			return
		var left := flip_h != (shoot_turn >= 0.5)
		var angle := facing_angle() if rear_mount else (-yaw if left else yaw)
		if not scaled and absf(angle - hull_angle) < 2.0:
			return
		hull_angle = angle
		var rot := Basis(Vector3.UP, deg_to_rad(angle))
		var tilt := deg_to_rad(PEOPLE_TILT)
		var pixels := model_height() / (1.79 * cos(tilt))
		var vertical := Vector3(0.0, -cos(tilt), sin(tilt))
		outline = Rect2()
		for corner in hull_points:
			var p := rot * corner
			outline = outline.expand(Vector2(p.x, p.dot(vertical)) * pixels)
		if rear_mount:
			outline = Rect2(-turn_radius, outline.position.y, turn_radius * 2.0, outline.size.y)
		elif not long_model.is_empty():
			# Углы AABB выступают перед мордой при повороте. Передний край задан на модели.
			if left:
				outline = Rect2(-muzzle, outline.position.y, outline.end.x + muzzle, outline.size.y)
			else:
				outline.size.x = muzzle - outline.position.x
		_cache_outline()

	func _cache_outline() -> void:
		outline_area = outline.get_area()
		center_x = outline.get_center().x
		end_x = outline.end.x

	func separation_bound(pos: Vector2) -> Vector2:
		return Vector2(clampf(pos.x, separation_limits.x, separation_limits.y), pos.y)

	func screen_box() -> Rect2:
		var scale_ui := view.world.scale
		return Rect2(view.screen(visible_foot() + outline.position), outline.size * scale_ui)

	func body_width() -> float:
		return body_half * 2.0

	func walk_cap() -> float:
		# Скорость шага на экране: как в симуляции с запасом, но не меньше двух корпусов в секунду.
		return maxf(unit.speed * 66.0 * 1.6, body_width() * 2.4)

	func rear_spacing() -> float:
		return maxf(beam * 2.80, 154.0)

	func guard_priority() -> int:
		if contact_front == null:
			return 0
		return 2 if contact_front.unit.key == "charioteer" else 1

	func holds_chariot() -> bool:
		return guard_priority() == 2 and contact_front.contact_blend >= 0.95

	func edge_toward(dir: float) -> float:
		if rear_mount or (wide and long_model.is_empty() and not hull_points.is_empty()):
			return -outline.position.x if dir < 0.0 else outline.end.x
		return muzzle if (dir < 0.0) == flip_h else rump

	func front_clearance() -> float:
		return strike_distance * (0.58 if long_model.is_empty() else 0.04)

	func can_strike(target: Fighter) -> bool:
		var d := target.body_ground() - body_ground()
		var source_edge := edge_toward(d.x) if wide and long_model.is_empty() else muzzle
		var gap := Vector2(maxf(0.0, absf(d.x) - source_edge - target.edge_toward(-d.x)), d.y)
		if gap.length_squared() > strike_distance * strike_distance or flip_h != (d.x < 0.0):
			return false
		if view == null or view.legacy_layout:
			return true
		if target.contact_front == self and target.holds_chariot():
			var front_gap := absf(d.x) - source_edge - target.edge_toward(-d.x)
			if absf(front_gap) > target.body_width() * 0.12:
				return false
		var relative_box := Rect2(outline.position - d, outline.size)
		var shared := relative_box.intersection(target.outline).get_area()
		if shared > minf(outline.get_area(), target.outline.get_area()) * 0.29:
			return false
		if layout_target == target and slot in [2, 3]:
			var primary := target.primary_attacker
			if is_instance_valid(primary) and primary != self and primary.unit.alive:
				var front := primary.position - target.position
				if front.x * -d.x < 0.0 and absf(d.x) >= target.body_width() * 0.30:
					return true
				var delta := position - primary.position
				var local_box := Rect2(outline.position + delta, outline.size)
				var common := local_box.intersection(primary.outline).get_area()
				var separated := common <= minf(local_box.get_area(), primary.outline.get_area()) * 0.22
				return separated and absf(delta.y) >= 27.0 and absf(d.y) >= 24.0
		return true

	func aim_at(target: Fighter) -> void:
		var d := target.body_ground() - body_ground()
		face(d.x < 0.0)
		# Нос длинной модели должен оставаться на рассчитанной границе.
		aim_depth = clampf(d.y * 0.23, -13.0, 13.0) if long_model.is_empty() else 0.0

	func layout_point(x: float, z: float) -> Vector2:
		if view != null and not view.legacy_layout:
			var depth := clampf((z if LegionBattleView.SIM_POSITIONS else lerpf(lane_z, z, 0.30)) * LegionBattleView.DEPTH_SCALE, -view._trail_depth, view._trail_depth)
			var sx := clampf(x * 66.0, -box_limit(), box_limit())
			if rear and not LegionBattleView.SIM_POSITIONS:
				var row := (unit.id % 3) - 1
				sx = side_dir * (REAR_X - body_half * 0.45 + row * 37.0)
				depth = clampf(depth + row * 14.0, -view._trail_depth, view._trail_depth)
			return Vector2(sx, depth)
		# В бою симуляция сближает ряды. На экране оставляем каждому бойцу свой проход.
		var depth := lerpf(lane_z, z, 0.28)
		var p := LegionBattleView.point(x, depth)
		if absf(lane_z) > 1.25:
			# На широком фланге сохраняем разнос в глубину, но сдерживаем боковой сдвиг.
			var inner := clampf(depth, -1.25, 1.25)
			p.x = LegionBattleView.point(x, lerpf(inner, depth, 0.28)).x
		if unit.row > 0 or unit.ranged():
			p.x = maxf(-692.0, p.x - 242.0) if unit.side == "ally" else p.x + 72.0
			p.y -= 30.0
		if wide:
			p.y = WIDE_LANE_Y - wide_lane * WIDE_LANE_STEP
			if unit.ranged():
				# Конные лучники держат дистанцию и не сходятся на одной экранной точке.
				p.x -= minf(340.0, wide_lane * 168.0)
		elif in_wide_wave and p.y < -90.0:
			# Сохраняем разнос дальних пеших рядов перед крупными врагами.
			p.y = maxf(WIDE_LANE_Y + 12.0, lerpf(-90.0, p.y, 0.30))
		return p

	func box_limit() -> float:
		return 502.0 - minf(104.0, body_half * 0.40)

	func body_height() -> float:
		if actor_height > 0.0:
			return model_height() * actor_height / 1.79
		var y := 26.0 if sheet == "bear" and sprite != null and sprite.animation == &"attack" else silhouette.y
		return (LegionBattleView.BASELINE - y) * scale.y

	func model_height() -> float:
		return 234.0 * scale.y if actor_height > 0.0 else body_height()

	func contact_point() -> Vector2:
		if view != null and not view.legacy_layout:
			return position + Vector2(-muzzle if flip_h else muzzle, 0.0)
		return position + contact_adjust

	func body_ground() -> Vector2:
		if long_model.is_empty() or (view != null and not view.legacy_layout):
			return position
		# Конь лучника разворачивается на месте, сохраняя опору корпуса.
		var outline: Vector2 = long_model[0]
		var angle := deg_to_rad(yaw)
		var front := (outline.x * cos(angle) + outline.y * sin(angle)) * model_height() / (1.79 * cos(deg_to_rad(PEOPLE_TILT)))
		return contact_point() + Vector2(front if flip_h else -front, 0)

	func visible_foot() -> Vector2:
		return drawn_foot if actor != null and view != null and not view.legacy_layout else body_ground()

	func head() -> Vector2:
		return visible_foot() - Vector2(0, body_height() + 10.0) if long_model.is_empty() else bar_mark

	func chest() -> Vector2:
		return visible_foot().lerp(head(), 0.55) if long_model.is_empty() else hit_mark

	func backward_shot() -> bool:
		return boss_model != null and unit.key == "horseArcher" and shoot_turn > 0.0

	func facing_angle() -> float:
		return (yaw + aim_depth - 180.0 * smoothstep(0.0, 1.0, shoot_turn)) * (-1.0 if flip_h else 1.0)

	func attack(action := "") -> void:
		if action.is_empty() and actor != null and actor.ranged != null:
			return # Кадр выпуска задаёт событие снаряда.
		if sprite != null:
			sprite.stop()
			sprite.play(&"attack")
		else:
			clip = attack_clip if action.is_empty() else action
			sample = 0.0
			attack_left = actor.clip_length(clip)
			hit_left = 0.0

	func release_ranged() -> void:
		ranged_winding = false
		clip = attack_clip
		sample = release_time
		attack_left = actor.clip_length(clip) - sample
		hit_left = 0.0
		ranged_mix = 1.0
		aim_target = null
		release_frame = Engine.get_process_frames()

	func hurt() -> void:
		flash = 0.14
		modulate = Color(1.8, 1.24, 1.12)
		if actor != null and not hit_clip.is_empty() and unit.alive and (actor.ranged == null or clip != attack_clip) and (boss_model == null or attack_left <= 0.0):
			clip = hit_clip
			sample = 0.0
			attack_left = 0.0
			hit_left = minf(actor.clip_length(hit_clip), 0.24)

	func revive() -> void:
		death = 0.0
		modulate = Color.WHITE
		attack_left = 0.0
		hit_left = 0.0
		clip = idle_clip
		sample = 0.0
		shoot_turn = 0.0
		aim_target = null
		ranged_mix = 1.0
		if sprite != null:
			sprite.play(&"idle")

	func death_ground() -> float:
		if actor == null or death_clip.is_empty():
			return 0.70
		return 0.88 if boss_model != null else 0.52

	func tick(gdt: float, rate: float, weight: float, fighting: bool, now: float, heal_due := INF) -> void:
		ranged_winding = false
		if not unit.alive:
			if sprite != null:
				sprite.speed_scale = 0.0
			if actor != null and not death_clip.is_empty():
				var duration := 1.38 if boss_model == null else (1.42 if unit.key == "elephant" else 1.17)
				death = minf(1.0, death + gdt / duration)
				clip = death_clip
				sample = minf(0.999, death / (0.94 if boss_model != null else 0.52)) * actor.clip_length(death_clip)
				modulate.a = 1.0 - smoothstep(0.39 if boss_model != null else 0.60, 1.0, death)
				ranged_mix = 1.0
			else:
				death = minf(1.0, death + gdt / 0.63)
				modulate.a = 1.0 - death
			return
		flash = maxf(0.0, flash - gdt)
		modulate = Color.WHITE.lerp(Color(1.8, 1.24, 1.12), flash / 0.14)
		health = lerpf(health, unit.hp_frac(), weight)
		var dx := travel.x
		var walking := travel.length_squared() > (gdt * 8.0) ** 2 and gdt > 0.0 and fighting
		if view == null or view.legacy_layout:
			var p := layout_point(unit.x, unit.z)
			var direction_x := p.x - position.x
			dx = direction_x * weight
			position = position.lerp(p, weight)
			if unit.side == "enemy":
				if unit.entering:
					face(unit.enter_dir < 0.0)
				elif unit.target != null and unit.target.alive and absf(unit.target.x - unit.x) > 0.16:
					face(unit.target.x < unit.x)
				elif unit.moving and absf(direction_x) > 3.0:
					face(direction_x < 0.0)
			walking = (unit.moving or unit.entering) and fighting
		var walk_rate := clampf(unit.speed / 1.5, 0.7, 1.65)
		if boss_model != null:
			boss_model.moving = walking
			var direction := -1.0 if flip_h else 1.0
			boss_model.roll(dx * direction * 1.79 / (model_height() * sin(deg_to_rad(yaw))))
		if sprite != null:
			if sprite.animation != &"attack" or not sprite.is_playing():
				sprite.play(&"walk" if walking else &"idle")
			sprite.speed_scale = rate * (walk_rate if sprite.animation == &"walk" else 1.0)
		elif hit_left > 0.0:
			sample += minf(gdt, maxf(0.0, hit_left - 0.001))
			hit_left = maxf(0.0, hit_left - gdt)
		elif attack_left > 0.0:
			if release_frame != Engine.get_process_frames():
				sample += minf(gdt, maxf(0.0, attack_left - 0.001))
				attack_left = maxf(0.0, attack_left - gdt)
		elif actor.ranged != null and _ranged_windup(gdt, now, fighting, heal_due):
			pass
		elif boss_model != null and fighting and _windup(now):
			clip = "Windup"
			var length := actor.clip_length(clip)
			sample = clampf(length - unit.timer, 0.0, length)
		else:
			var next := walk_clip if walking else idle_clip
			sample = sample + gdt * (walk_rate if walking else 1.0) if clip == next else 0.0
			clip = next
		if unit.key == "horseArcher" and boss_model != null:
			var retreat := not unit.entering and unit.target != null and unit.target.alive
			shoot_turn = move_toward(shoot_turn, float(retreat), gdt / 0.32)

	func heal_due(sim: LegionSim, fighting: bool) -> float:
		if not fighting or not unit.alive or unit.heal_pow <= 0.0 or unit.heal_t > RangedPose.RELEASES[RangedPose.CAST]:
			return INF
		if heal_step != sim.steps:
			heal_step = sim.steps
			heal_ready = false
			for ally: LegionSim.Unit in sim.units:
				if ally.alive and ally.side == unit.side and ally.hp < ally.max_hp and LegionSim.dist(unit, ally) <= unit.range_m:
					heal_ready = true
					break
		return unit.heal_t if heal_ready else INF

	func _ranged_windup(gdt: float, now: float, fighting: bool, heal_due: float) -> bool:
		var due := heal_due
		var target := unit.target
		var valid := fighting and not unit.entering and unit.stun_t <= now
		var release := release_time
		if valid and target != null and target.alive:
			var fast := unit.horn_k if unit.horn > now else 1.0
			var cooldown := unit.timer / fast
			if cooldown <= release and cooldown < due:
				var distance := LegionSim.dist(unit, target)
				var reach := unit.range_m + 0.35 * (unit.size + target.size - 2.0)
				if distance + 0.01 >= unit.min_range:
					var approach := maxf(0.0, distance - reach) / maxf(0.01, unit.speed * fast)
					due = minf(due, approach + cooldown)
		if valid and due <= release and (aim_target == null or aim_target.alive):
			if clip != attack_clip or sample >= release or ranged_mix < 1.0:
				clip = attack_clip
				sample = 0.0
			sample = minf(release - 0.001, move_toward(sample, maxf(0.0, release - due), gdt * 2.0))
			if due < heal_due:
				aim_target = target
				ranged_winding = true
			ranged_mix = 1.0
			return true
		if clip == attack_clip and sample < release:
			ranged_mix = move_toward(ranged_mix, 0.0, gdt / RangedPose.BLEND)
			if ranged_mix > 0.0:
				return true
		aim_target = null
		ranged_mix = 1.0
		return false

	func _windup(now: float) -> bool:
		if unit.key != "cyclops" or unit.entering or unit.target == null or not unit.target.alive:
			return false
		if unit.stun_t > now:
			return false
		var distance := LegionSim.dist(unit, unit.target)
		var reach := unit.range_m + 0.35 * (unit.size + unit.target.size - 2.0)
		return distance <= reach + 0.05 and unit.timer < actor.clip_length("Windup")

	func status(t: float, fighting: bool) -> void:
		status_color = Color.TRANSPARENT
		if (unit.summon_warned or unit.abil_warned) and fighting:
			status_color = LegionBattleView.ALERT
		elif unit.testudo > t or unit.eagle > t:
			status_color = LegionBattleView.GOLD
		elif unit.burn > t or unit.horn > t or unit.rage_t > t:
			status_color = Color("ffa241")
		elif unit.ward_t > t:
			status_color = Color("89bfff")
		elif not unit.poison.is_empty():
			status_color = LegionBattleView.HEAL


class Burst extends AnimatedSprite2D:
	var age := 0.0


class Flight extends Burst:
	var origin := Vector2.ZERO
	var target := Vector2.ZERO


class GroundLayer extends Node2D:
	var views := {}
	var crowds: Array = []
	var marks: Array[Dictionary] = []
	var lanes: Array[Dictionary] = []
	var time := 0.0
	var shadow: GradientTexture2D

	func _ready() -> void:
		shadow = GradientTexture2D.new()
		shadow.width = 64
		shadow.height = 64
		shadow.fill = GradientTexture2D.FILL_RADIAL
		shadow.fill_from = Vector2(0.5, 0.5)
		shadow.fill_to = Vector2(1.0, 0.5)
		shadow.gradient = Gradient.new()
		shadow.gradient.offsets = PackedFloat32Array([0.0, 0.84, 1.0])
		shadow.gradient.colors = PackedColorArray([Color(1, 1, 1, 0.41), Color(1, 1, 1, 0.31), Color(1, 1, 1, 0)])

	func tick(dt: float) -> void:
		time += dt
		_age_marks(marks, dt)
		_age_marks(lanes, dt)
		queue_redraw()

	func _age_marks(list: Array[Dictionary], dt: float) -> void:
		for i in range(list.size() - 1, -1, -1):
			list[i]["t"] = float(list[i]["t"]) - dt
			if float(list[i]["t"]) <= 0.0:
				list.remove_at(i)

	func _draw() -> void:
		for lane_mark in lanes:
			var z := float(lane_mark["z"])
			var tint: Color = lane_mark["color"]
			tint.a *= sin(float(lane_mark["t"]) / float(lane_mark["lifetime"]) * PI) * 0.7
			draw_line(LegionBattleView.point(-15.0, z), LegionBattleView.point(15.0, z), tint, float(lane_mark["width"]), true)
		for id in views:
			var f: Fighter = views[id]
			var foot := f.visible_foot() + (f.contact_point() - f.body_ground()) * 0.34 + Vector2(0, 2)
			var r := (65.0 if f.wide else 39.0) * f.scale.x
			var tint := Color(0.24, 0.11, 0.04, f.modulate.a)
			var aspect := 0.18 if f.wide else 0.22
			var fallen := f.death > 0.16 and f.actor != null and f.actor._fallen
			if fallen:
				var k := smoothstep(0.16, 0.52, f.death)
				var at := f.actor._fall_point(0).lerp(f.actor._fall_point(1), 0.5)
				var offset := f.actor.basis * Vector3(at.x, 0, at.z)
				foot += Vector2(offset.x, offset.z * sin(deg_to_rad(PEOPLE_TILT))) * (f.model_height() / 1.79) / f.actor.scale.x
				r *= lerpf(1.0, 2.1, k)
				aspect = lerpf(aspect, 0.16, k)
			draw_set_transform(foot, 0.0, Vector2(1.0, aspect))
			var half := Vector2.ONE * r * 1.15
			draw_texture_rect(shadow, Rect2(-half, half * 2.0), false, tint)
			if f.unit.alive and f.status_color.a > 0.0:
				_ellipse(foot, r * (1.15 + sin(time * 6.0) * 0.08), f.status_color)
		for m in marks:
			var col: Color = m["color"]
			col.a *= minf(1.0, float(m["t"]) * 4.0)
			_ellipse(m["pos"], float(m["radius"]) * lerpf(1.18, 0.9, float(m["t"]) / float(m["lifetime"])), col)
		for c: Dictionary in crowds:
			_ellipse(c["position"], 118.0 * (1.0 + sin(time * 5.0) * 0.08), LegionBattleView.ALERT)
		draw_set_transform(Vector2.ZERO)

	func _ellipse(where: Vector2, radius: float, color: Color) -> void:
		draw_set_transform(where, 0.0, Vector2(1.0, 0.28))
		draw_circle(Vector2.ZERO, radius, Color(color, color.a * 0.14), true, -1.0, true)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, color, 3.0, true)
