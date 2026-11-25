class_name LegionBattleView
extends Control

const Perf14 = preload("res://scripts/perf14_timers.gd")
const Perf13 = preload("res://scripts/perf13_timers.gd")
## Рисованное поле боя. Читает позы и события LegionSim, не меняет состояние боя.

signal field_sound(event: String, pan: float)
signal melee_pose(source: Fighter, target: Fighter)
signal melee_event(source: Fighter, target: Fighter)

const FIGURE_SCALE := 0.64
const REAR_X := 657.0
const TRAIL_DEPTH := [114.0, 120.0, 120.0, 126.0]

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
const FOLLOW_OMEGA := 46.0
const FACE_HOLD := 0.12
const PASS_DEPTH := 35.0
const QUEUE_GAP := 0.60
const FRONT_WALK := 115.0
const STRIKE_WAIT := 0.75
const STRIKE_HOLD := 0.22
const STRIKE_DEPTH := 0.43

enum Pass { NONE, APPROACH, CROSS, REAR, RETURN, CROSS_HOME }
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
var _trail_depth := 114.0
var _field_bounds := Rect2()
var _fighters: Array[Fighter] = []
var _display_order: Array[Fighter] = []
var _front_active := false
var _front_x := 0.0
var _front_goal := 0.0
var _front_rows := 3
var _row_extent := 0.0
var _arrival_order := 0
var _ally_line := FrontLine.new(-1.0)
var _enemy_line := FrontLine.new(1.0)
var _raiders: Array[Fighter] = []
var melee_requests := 0
var melee_played := 0
var _spawn_layout := false
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
var profile_display := false
var display_usec := 0
var display_gaps_usec := 0
var layout_usec := 0


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
	f.face(u.side == "enemy" and (not legacy_layout or not u.entering or u.enter_dir < 0.0))
	f.measure_body()
	f.position = f.layout_point(u.x, u.z)
	if not legacy_layout:
		f.position = _fit_foot(f, f.position)
		if _front_active:
			f.position.x = _front_x + f.side_dir * maxf(f.body_half, (f.position.x - _front_x) * f.side_dir)
	f.layout_pos = f.position
	_place_actor(f)
	views[u.id] = f
	_fighters.append(f)
	_spawn_layout = true
	_layout_step = -1
	if not legacy_layout and f.wide:
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


func _place_actor(f: Fighter, rate := 1.0, force_pose := false, keep_pose := false) -> void:
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
	if f.actor.visible and not keep_pose:
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
	melee_requests += int(action.is_empty())
	if legacy_layout:
		source.attack(action)
		melee_played += int(action.is_empty())
		melee_pose.emit(source, target)
		return
	source.strike_target = target
	source.strike_action = action
	source.strike_wait = STRIKE_WAIT
	# Смерть уже записана симуляцией, но последний удар ещё виден в прежнем строю.
	if source.unit.alive and not source.rear and source.can_strike(target) and _may_strike(source):
		_play_strike(source, target)
	_layout_step = -1


func _may_strike(f: Fighter) -> bool:
	return not _front_active or f.rank == 0 or f.pass_phase in [Pass.CROSS, Pass.REAR]


func _play_strike(source: Fighter, target: Fighter) -> void:
	source.strike_wait = 0.0
	source.attack(source.strike_action)
	source.strike_hold = STRIKE_HOLD
	melee_played += int(source.strike_action.is_empty())
	melee_pose.emit(source, target)


func _fit_foot(f: Fighter, pos: Vector2) -> Vector2:
	var lo := _field_bounds.position.x - f.outline.position.x + 12.0
	var hi := _field_bounds.end.x - f.end_x - 12.0
	if f.unit.entering and not f.rear:
		lo = _field_bounds.position.x + 12.0
		hi = _field_bounds.end.x - 12.0
	var x := clampf(pos.x, lo, hi)
	if _front_active and f.on_own_side():
		x = _front_x + f.side_dir * maxf(0.0, (x - _front_x) * f.side_dir)
	return Vector2(x, clampf(pos.y, -_trail_depth, _trail_depth))


func _plan_layout(sim_dt: float) -> void:
	var started := Perf13.begin()
	_ally_line.reset(_field_bounds.position.x)
	_enemy_line.reset(_field_bounds.end.x)
	_raiders.clear()
	for f in _fighters:
		f.queue_ahead = null
		f.front_guard = false
		f.rank = -1
		f.front_attackers = 0
		f.layout_target = null
		if not f.unit.alive:
			f.front_row = -1
			f.pass_phase = Pass.NONE
			continue
		var line := _ally_line if f.side_dir < 0.0 else _enemy_line
		var u := f.unit
		f.goal = f.layout_point(u.x, u.z)
		if u.entering and u.enter_dir > 0.0:
			f.goal.x = absf(f.goal.x)
		if u.target != null and u.target.alive:
			f.layout_target = views.get(u.target.id)
		if f.rear:
			line.rear.append(f)
		elif u.entering:
			line.entering.append(f)
		else:
			line.melee.append(f)
			if line.lead == null or u.x * f.side_dir < line.lead.unit.x * f.side_dir:
				line.lead = f
		if f.pass_phase != Pass.NONE:
			_raiders.append(f)

	var ally := _ally_line.lead
	var enemy := _enemy_line.lead
	if not _front_active and ally != null and enemy != null:
		for f in _fighters:
			var target := f.layout_target
			if f.rear or target == null or target.rear or f.unit.entering or target.unit.entering:
				continue
			var reach := f.unit.range_m + 0.35 * (f.unit.size + target.unit.size - 2.0)
			if LegionSim.dist(f.unit, target.unit) <= reach + 1.20:
				_start_front(ally, enemy)
				break

	if _front_active:
		_plan_passes(_ally_line, _enemy_line)
		_plan_passes(_enemy_line, _ally_line)
		_plan_front()
		_guard_duels(_ally_line)
		_guard_duels(_enemy_line)
		_place_ranks(_ally_line, _enemy_line)
		_place_ranks(_enemy_line, _ally_line)

		var desired := _front_goal
		if ally != null and enemy != null:
			desired = (ally.unit.x + enemy.unit.x) * 33.0
		elif ally != null and not _enemy_line.rear.is_empty():
			var rear := _first_rear(_enemy_line)
			desired = rear.goal.x - rear.edge_toward(-1.0) - 3.0
		elif enemy != null and not _ally_line.rear.is_empty():
			var rear := _first_rear(_ally_line)
			desired = rear.goal.x + rear.edge_toward(1.0) + 3.0
		var lo := _field_bounds.position.x + _ally_line.room
		var hi := _field_bounds.end.x - _enemy_line.room
		if lo <= hi:
			_front_goal = clampf(desired, lo, hi)
		else:
			# Делим недостающее место между сторонами, оставляя место у носа крупных моделей.
			var front_lo := _field_bounds.position.x + _ally_line.front_room
			var front_hi := _field_bounds.end.x - _enemy_line.front_room
			_front_goal = clampf((lo + hi) * 0.5, front_lo, front_hi) if front_lo <= front_hi else (front_lo + front_hi) * 0.5
		_front_x = move_toward(_front_x, _front_goal, FRONT_WALK * sim_dt)
		# Граница не проходит через живого бойца, пока строй отходит.
		for f in _fighters:
			if f.unit.alive and not f.spawn_pending and f.on_own_side():
				_front_x = maxf(_front_x, f.position.x) if f.side_dir < 0.0 else minf(_front_x, f.position.x)
			if f.rank >= 0:
				f.goal.x += _front_x
	else:
		for line: FrontLine in [_ally_line, _enemy_line]:
			for f in line.melee:
				line.back_center = maxf(line.back_center, f.goal.x * line.side)
	for line: FrontLine in [_ally_line, _enemy_line]:
		_place_rear(line)
		_stage_entrants(line)
	for f in _fighters:
		if f.unit.alive and f.pass_phase == Pass.NONE:
			f.layout_pos = _fit_foot(f, f.goal)
	Perf13.end(Perf13.PLAN, started)


func _start_front(ally: Fighter, enemy: Fighter) -> void:
	_front_active = true
	_front_goal = (ally.unit.x + enemy.unit.x) * 33.0
	_front_x = (ally.position.x + enemy.position.x) * 0.5
	var left := _field_bounds.position.x
	var right := _field_bounds.end.x
	var height := 0.0
	var count := 0
	for f in _fighters:
		if not f.unit.alive:
			continue
		if f.side_dir < 0.0:
			left = maxf(left, f.position.x)
		else:
			right = minf(right, f.position.x)
		if not f.rear and not f.wide and not f.unit.boss:
			height += f.body_height()
			count += 1
	_front_x = clampf(_front_x, left, right) if left <= right else (left + right) * 0.5
	var spacing := maxf(55.0, 0.45 * height / maxi(1, count))
	_front_rows = clampi(maxi(_ally_line.melee.size(), _enemy_line.melee.size()), 3, 5)
	_row_extent = minf(_trail_depth - 12.0, spacing * (_front_rows - 1) * 0.55)
	_record_arrivals(_ally_line)
	_record_arrivals(_enemy_line)


func _record_arrivals(line: FrontLine) -> void:
	line.melee.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		var ax := a.position.x * line.side
		var bx := b.position.x * line.side
		return ax < bx if not is_equal_approx(ax, bx) else a.unit.id < b.unit.id)
	for f in line.melee:
		if f.arrival_order == 0:
			_arrival_order += 1
			f.arrival_order = _arrival_order


func _plan_passes(line: FrontLine, foes: FrontLine) -> void:
	for f in line.melee:
		var target := f.layout_target
		var attack_rear := target != null and (target.rear or target.unit.row == 1)
		var sent_through := foes.lead != null and (f.unit.x - foes.lead.unit.x) * line.side < -0.45
		var wants_pass := attack_rear and foes.lead != null and (f.unit.backline or sent_through)
		wants_pass = wants_pass and (not f.wide or sent_through)
		if f.pass_phase == Pass.NONE:
			if not wants_pass or (f.was_front and f.strike_hold > 0.0):
				continue
			var lane := -1.0 if f.position.y < 0.0 else 1.0
			for other in _raiders:
				if other.pass_lane == lane:
					lane = -lane
					break
			var occupied := false
			for other in _raiders:
				occupied = occupied or other.pass_lane == lane
			if occupied:
				continue
			f.pass_lane = lane
			f.pass_phase = Pass.APPROACH
			f.front_row = -1
			_raiders.append(f)
		elif not attack_rear:
			if f.pass_phase == Pass.APPROACH:
				f.pass_phase = Pass.NONE
				_raiders.erase(f)
			elif f.pass_phase == Pass.CROSS or f.pass_phase == Pass.REAR:
				f.pass_phase = Pass.RETURN


func _row_span(f: Fighter) -> int:
	if f.wide or f.unit.boss:
		return mini(_front_rows, 3 if f.body_width() > 300.0 else 2)
	return 1


func _row_depth(row: int, span: int) -> float:
	return lerpf(-_row_extent, _row_extent, (row + (span - 1) * 0.5) / (_front_rows - 1))


func _plan_front() -> void:
	var pairs: Array[Fighter] = []
	for line: FrontLine in [_ally_line, _enemy_line]:
		for f in line.melee:
			if f.arrival_order == 0:
				_arrival_order += 1
				f.arrival_order = _arrival_order
			f.duel_weight = 0.0
			f.incoming = 0
	for line: FrontLine in [_ally_line, _enemy_line]:
		for f in line.melee:
			var target := f.layout_target
			if f.pass_phase == Pass.NONE and target != null and not target.rear and not target.unit.entering \
					and target.pass_phase == Pass.NONE:
				pairs.append(f)
				target.incoming += 1
	for f in pairs:
		var target := f.layout_target
		var reach := f.unit.range_m + 0.35 * (f.unit.size + target.unit.size - 2.0)
		var walking := maxf(0.0, LegionSim.dist(f.unit, target.unit) - reach)
		f.duel_weight = 24.0 * mini(target.incoming, 3) - minf(walking, 4.0) * 48.0
		f.duel_weight += 72.0 if f.duel_with == target.unit.id and f.was_front and target.was_front else 0.0
		f.duel_weight += 45.0 if target.layout_target == f else 0.0
		f.duel_weight += 28.0 if f.strike_wait > 0.0 else 0.0
		f.duel_weight += 28.0 if f.unit.boss or target.unit.boss else 0.0
		f.duel_weight -= minf(f.unit.timer, 2.0) * 8.0
	pairs.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.duel_weight > b.duel_weight if a.duel_weight != b.duel_weight else a.unit.id < b.unit.id)
	for f in pairs:
		var target := f.layout_target
		if target.front_attackers < 3 and _seat_duel(f, target):
			target.front_attackers += 1
			f.duel_with = target.unit.id
		else:
			f.duel_with = -1
	for line: FrontLine in [_ally_line, _enemy_line]:
		_fill_front(line)
		for f in line.melee:
			f.was_front = f.rank == 0


func _seat_duel(f: Fighter, target: Fighter) -> bool:
	if f.rank == 0 and target.rank == 0:
		return f.neighbouring_row(target)
	var line := _ally_line if f.side_dir < 0.0 else _enemy_line
	var foes := _enemy_line if f.side_dir < 0.0 else _ally_line
	var a_span := _row_span(f)
	var b_span := _row_span(target)
	var best := INF
	var a_row := -1
	var b_row := -1
	for a in range(_front_rows + 1 - a_span):
		var a_mask := ((1 << a_span) - 1) << a
		if not _can_use_row(line, f, a, a_mask):
			continue
		for b in range(_front_rows + 1 - b_span):
			var b_mask := ((1 << b_span) - 1) << b
			if ((a_mask | (a_mask << 1) | (a_mask >> 1)) & b_mask) == 0 or not _can_use_row(foes, target, b, b_mask):
				continue
			var score := _row_cost(f, a, a_span) + _row_cost(target, b, b_span)
			score += absf(_row_depth(a, a_span) - _row_depth(b, b_span)) * 0.72
			if score < best:
				best = score
				a_row = a
				b_row = b
	if a_row < 0:
		return false
	if f.rank != 0:
		_claim_front(line, f, a_row)
	if target.rank != 0:
		_claim_front(foes, target, b_row)
	return true


func _can_use_row(line: FrontLine, f: Fighter, row: int, mask: int) -> bool:
	return row == f.front_row if f.rank == 0 else (line.front_mask & mask) == 0


func _row_cost(f: Fighter, row: int, span: int) -> float:
	var depth := _row_depth(row, span)
	var cost := absf(depth - f.position.y) * 0.60 + absf(depth) * 0.17
	if f.incoming > 1:
		cost += absf(depth) * 0.50 * mini(3, f.incoming - 1)
	if f.was_front:
		cost += 86.0 if row != f.front_row else -32.0
	return cost


func _fill_front(line: FrontLine) -> void:
	while line.front_mask < (1 << _front_rows) - 1:
		var chosen: Fighter
		var row := 0
		var best := INF
		for f in line.melee:
			if f.rank == 0 or f.pass_phase != Pass.NONE:
				continue
			var span := _row_span(f)
			for r in range(_front_rows + 1 - span):
				if line.front_mask & (((1 << span) - 1) << r):
					continue
				var score := _row_cost(f, r, span) + absf(f.position.x - _front_x) * 0.36
				if score < best:
					best = score
					chosen = f
					row = r
		if chosen == null:
			break
		_claim_front(line, chosen, row)


func _claim_front(line: FrontLine, f: Fighter, row: int) -> void:
	f.front_row = row
	f.row_mask = ((1 << _row_span(f)) - 1) << row
	f.rank = 0
	line.front.append(f)
	line.front_mask |= f.row_mask


func _guard_duels(line: FrontLine) -> void:
	for f in line.front:
		var target := f.layout_target
		if target != null and target.rank == 0 and f.neighbouring_row(target) \
				and (not f.long_model.is_empty() or not target.long_model.is_empty()):
			f.front_guard = true
			target.front_guard = true


func _place_ranks(line: FrontLine, foes: FrontLine) -> void:
	for f in line.front:
		var foe := f.layout_target
		var span := _row_span(f)
		var depth := _row_depth(f.front_row, span)
		if foe != null and foe.rear and foes.lead == null and line.front.size() == 1:
			depth = foe.goal.y
		var edge := f.edge_toward(-line.side)
		var clearance := 2.0 if f.front_guard else 4.0
		var stagger := 0.0
		if not f.wide and line.front.size() > 1:
			var parity := f.front_row % 2
			var at_nose := (f.front_guard and foe != null and not foe.long_model.is_empty()
				and absf(depth - _row_depth(foe.front_row, _row_span(foe))) < 30.0)
			stagger = 23.0 if not at_nose and parity == (0 if line.side > 0.0 else 1) else 0.0
		f.goal = Vector2(line.side * (edge + clearance + stagger), depth)
		_mark_rank(line, f)

	line.front_room = line.back + 16.0
	# Занимаем первое свободное место ряда. Крупная модель закрывает несколько рядов.
	line.melee.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.arrival_order < b.arrival_order)
	for f in line.melee:
		if f.rank == 0 or f.pass_phase != Pass.NONE:
			continue
		var span := _row_span(f)
		var best := INF
		var best_row := 0
		var ahead: Fighter
		for row in range(_front_rows + 1 - span):
			var edge := 0.0
			var previous: Fighter
			for r in range(row, row + span):
				if line.edges[r] >= edge:
					edge = line.edges[r]
					previous = line.tails[r]
			var cost := edge + absf(_row_depth(row, span) - f.position.y) * 0.50
			if previous == null and not line.front.is_empty():
				cost += line.front[0].body_width() * 1.55
			if row == f.front_row:
				cost -= f.body_width() * 1.60
			if cost < best:
				best = cost
				best_row = row
				ahead = previous
		f.front_row = best_row
		f.row_mask = ((1 << span) - 1) << best_row
		f.queue_ahead = ahead
		f.rank = (ahead.rank + 1) if ahead != null else 1
		var back := ahead.goal.x * line.side + ahead.edge_toward(line.side) if ahead != null else 0.0
		var distance := back + f.edge_toward(-line.side) + QUEUE_GAP * f.body_width()
		var y := _row_depth(best_row, span)
		f.goal = Vector2(line.side * distance, y)
		_mark_rank(line, f)

	line.room = line.back + 16.0
	var mount_room := 0.0
	for f in line.rear:
		line.room = maxf(line.room, line.back_center + f.rear_spacing() + f.edge_toward(line.side) + mount_room + 16.0)
		if f.rear_mount:
			mount_room += f.edge_toward(line.side) + f.edge_toward(-line.side) + 12.0


func _mark_rank(line: FrontLine, f: Fighter) -> void:
	var center := f.goal.x * line.side
	var edge := center + f.edge_toward(line.side)
	line.back = maxf(line.back, edge)
	line.back_center = maxf(line.back_center, center)
	for row in _front_rows:
		if f.row_mask & (1 << row):
			line.edges[row] = edge
			line.tails[row] = f


func _first_rear(line: FrontLine) -> Fighter:
	var first := line.rear[0]
	for f in line.rear:
		if f.position.x * line.side < first.position.x * line.side:
			first = f
	return first


func _stage_entrants(line: FrontLine) -> void:
	if line.entering.is_empty():
		return
	var wide: Array[Fighter] = []
	for f in line.entering:
		if f.wide:
			wide.append(f)
	if wide.is_empty():
		return
	wide.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		return a.unit.boss if a.unit.boss != b.unit.boss else a.unit.id < b.unit.id)
	var end := line.edge * line.side - 24.0
	for i in range(wide.size() - 1, -1, -1):
		var f := wide[i]
		var step := f.body_width() * 0.59
		var x := minf(f.goal.x * line.side, end)
		f.goal.x = line.side * x
		f.goal.y = clampf(f.goal.y + (1.0 if i % 2 == 0 else -1.0) * 46.0, -_trail_depth, _trail_depth)
		end = x - step


func _place_rear(line: FrontLine) -> void:
	var outer := line.edge * line.side - 12.0
	var mount_edge := outer
	for f in line.rear:
		if f.rear_mount:
			f.goal.x = line.side * (mount_edge - f.edge_toward(line.side))
			mount_edge = f.goal.x * line.side - f.edge_toward(-line.side) - 12.0
	for f in line.rear:
		var back := (_front_x * line.side if _front_active else 0.0) + line.back_center
		var outside := minf(outer, mount_edge) if not f.rear_mount else outer
		var x := minf(f.goal.x * line.side, outside - f.edge_toward(line.side))
		if not line.melee.is_empty() or not line.entering.is_empty():
			var needed := back + f.rear_spacing()
			if not f.rear_mount:
				x = minf(outer - f.edge_toward(line.side), maxf(x, needed))
			# При тесноте очередь сжимается у своего стрелкового ряда.
			for melee in line.melee:
				if melee.rank > 0 or not _front_active:
					melee.goal.x = line.side * minf(melee.goal.x * line.side, x - f.rear_spacing())
			for melee in line.entering:
				melee.goal.x = line.side * minf(melee.goal.x * line.side, x - f.rear_spacing())
		f.goal.x = line.side * x


func _pass_destination(f: Fighter) -> Vector2:
	var direction := -f.side_dir
	var y := f.pass_lane * _trail_depth
	var high := direction * (_field_bounds.end.x if direction > 0.0 else _field_bounds.position.x)
	var foes := _enemy_line if direction > 0.0 else _ally_line
	var target := f.layout_target
	var back := _front_x * direction + foes.back + f.body_half + 6.0
	if target != null:
		back = minf(back, target.position.x * direction - target.edge_toward(-direction) - f.muzzle - 4.0)
	var end_x := direction * minf(high - f.edge_toward(direction) - 12.0, back)
	match f.pass_phase:
		Pass.APPROACH:
			if absf(f.position.y - y) > 2.0:
				return Vector2(f.position.x, y)
			f.pass_phase = Pass.CROSS
		Pass.CROSS:
			if (f.position.x - end_x) * direction >= -3.0:
				f.pass_phase = Pass.REAR
		Pass.REAR:
			if target != null:
				var x := target.position.x - direction * (target.edge_toward(-direction) + f.muzzle + 4.0)
				return Vector2(x, target.position.y)
		Pass.RETURN:
			if absf(f.position.y - y) > 2.0:
				return Vector2(f.position.x, y)
			f.pass_phase = Pass.CROSS_HOME
		Pass.CROSS_HOME:
			if (f.position.x - _front_x) * f.side_dir >= f.body_half + 10.0:
				f.pass_phase = Pass.NONE
				_layout_step = -1
				return f.position
	if f.pass_phase == Pass.CROSS_HOME:
		end_x = _front_x + f.side_dir * (f.body_half + 14.0)
	return Vector2(end_x, y)


func _advance_display(gdt: float) -> void:
	var started := Time.get_ticks_usec() if profile_display else 0
	var decay := exp(-FOLLOW_OMEGA * gdt)
	_display_order.clear()
	for f in _fighters:
		if not f.unit.alive:
			continue
		f.travel = Vector2.ZERO
		f.display_passing = false
		f.step_limit = f.move_speed() * (1.30 * gdt)
		f.display_corrected = false
		_display_order.append(f)
		f.strike_hold = maxf(0.0, f.strike_hold - gdt)
		var firing := f.rear and (f.ranged_winding or f.attack_left > 0.0)
		var striking := f.strike_hold > 0.0 and is_instance_valid(f.strike_target) and f.can_strike(f.strike_target)
		if firing or striking:
			f.follow_velocity = Vector2.ZERO
			f.step_limit = 0.0
			continue
		if f.pass_phase != Pass.NONE:
			f.layout_pos = _fit_foot(f, _pass_destination(f))
		f.display_passing = f.pass_phase in [Pass.CROSS, Pass.CROSS_HOME]
		var destination := _front_route(f) if f.rank == 0 else f.layout_pos
		var offset := f.position - destination
		var impulse := f.follow_velocity + offset * FOLLOW_OMEGA
		# ?????? ??? ?????????? ?????????? ??????? ??? ??????? ????.
		var step := (offset + impulse * gdt) * decay - offset
		var limit := f.step_limit
		if step.length_squared() > limit * limit:
			step = step.limit_length(limit)
			f.follow_velocity = step / gdt
		else:
			f.follow_velocity = (f.follow_velocity - impulse * (FOLLOW_OMEGA * gdt)) * decay
		f.travel = step

	if started != 0:
		display_usec += Time.get_ticks_usec() - started
		started = Time.get_ticks_usec()
	_keep_display_gaps()
	if started != 0:
		display_gaps_usec += Time.get_ticks_usec() - started
	for f in _display_order:
		if _front_active and f.on_own_side():
			var advance := minf(0.0, (_front_x - f.position.x) * f.side_dir)
			f.travel.x = f.side_dir * maxf(advance, f.travel.x * f.side_dir)
		f.position += f.travel
		if f.display_corrected:
			f.follow_velocity = f.travel / gdt


func _front_route(f: Fighter) -> Vector2:
	var result := f.layout_pos
	var advance := (f.position.x - result.x) * f.side_dir
	if advance < f.body_half:
		return result
	var line := _ally_line if f.side_dir < 0.0 else _enemy_line
	var best := INF
	for other in line.melee:
		if other == f or other.rank <= 0:
			continue
		var dx := (f.position.x - other.position.x) * f.side_dir
		var depth_needed := minf(82.0, minf(f.body_half, other.body_half) * 1.20)
		if dx < -depth_needed or dx > minf(advance, other.edge_toward(f.side_dir) + f.body_half + 76.0):
			continue
		if absf(other.position.y - result.y) >= depth_needed:
			continue
		var cost := absf(dx)
		if cost < best:
			best = cost
			var away := signf(f.position.y - other.position.y)
			if absf(f.position.y - other.position.y) < 4.0:
				away = -1.0 if other.position.y > 0.0 else 1.0
			if absf(other.position.y + away * depth_needed) > _trail_depth:
				away = -away
			result.y = other.position.y + away * depth_needed
	return result


func _keep_display_gaps() -> void:
	var ally_back := -INF
	var enemy_back := -INF
	for f in _display_order:
		var bound := maxf(f.body_half, -f.outline.position.x)
		f.sweep_left = f.position.x - bound - f.step_limit - 12.0
	_display_order.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.sweep_left < b.sweep_left)
	for i in _display_order.size():
		var a := _display_order[i]
		var right := a.position.x + maxf(a.body_half, a.end_x) + a.step_limit + 12.0
		for j in range(i + 1, _display_order.size()):
			var b := _display_order[j]
			if b.sweep_left > right:
				break
			_display_pair(a, b)
	for f in _display_order:
		var ahead := f.queue_ahead
		if ahead == null or not ahead.unit.alive:
			continue
		var side := f.side_dir
		var gap := f.edge_toward(-side) + ahead.edge_toward(side) + QUEUE_GAP * f.body_width()
		var current := (f.position.x - ahead.position.x) * side
		var missing := gap - current - (f.travel.x - ahead.travel.x) * side
		if current > 0.0 and missing > 0.25:
			_push_display(f, side, missing)
	for f in _display_order:
		if not f.rear and f.on_own_side():
			var back := (f.position.x + f.travel.x) * f.side_dir
			if f.side_dir < 0.0:
				ally_back = maxf(ally_back, back)
			else:
				enemy_back = maxf(enemy_back, back)
	for f in _display_order:
		if f.rear:
			var back := ally_back if f.side_dir < 0.0 else enemy_back
			var missing := back + f.beam * 2.09 - (f.position.x + f.travel.x) * f.side_dir
			_push_display(f, f.side_dir, missing)


func _display_pair(a: Fighter, b: Fighter) -> void:
	var d := a.position + a.travel - b.position - b.travel
	var same_side := a.side_dir == b.side_dir
	var a_box := a.outline
	var b_box := b.outline
	var foot_order := a.position.x - b.position.x
	var side := signf(foot_order) if absf(foot_order) > 0.01 else a.side_dir
	if _front_active and not same_side and a.on_own_side() and b.on_own_side():
		side = a.side_dir
	var gap := 0.0
	var feet := minf(a.body_half, b.body_half) * 1.06
	if absf(d.y) < feet:
		gap = maxf(gap, sqrt(feet * feet - d.y * d.y))
	var edge := b_box.end.x - a_box.position.x if side > 0.0 else a_box.end.x - b_box.position.x
	if a.display_passing or b.display_passing:
		# Внешний проход идёт вдоль опор, а не через центры корпусов.
		pass
	elif (a.rear_mount or b.rear_mount) and (same_side or (a.on_own_side() and b.on_own_side())):
		gap = maxf(gap, edge + 6.0)
	elif same_side or a.wide or b.wide:
		var changing_rank := (same_side and ((a.rank == 0 and b.rank > 0 and side == a.side_dir)
			or (b.rank == 0 and a.rank > 0 and side != a.side_dir)))
		var height := minf(d.y + a_box.end.y, b_box.end.y) - maxf(d.y + a_box.position.y, b_box.position.y)
		if height > 0.0 and not (changing_rank and (a.long_model.is_empty() or b.long_model.is_empty())):
			var separate_rows := same_side and a.rank >= 0 and b.rank >= 0 and (a.row_mask & b.row_mask) == 0
			var tolerance := 0.21 if separate_rows else (0.15 if same_side else 0.10)
			var allowed := minf(a.outline_area, b.outline_area) * tolerance / height
			if allowed < minf(a_box.size.x, b_box.size.x):
				gap = maxf(gap, edge - allowed)
	var need := gap - d.x * side
	if gap <= 0.0 or need <= 0.25:
		return
	var share := 0.5
	if a.front_guard != b.front_guard:
		share = 0.0 if a.front_guard else 1.0
	elif a.rear != b.rear:
		share = 1.0 if a.rear else 0.0
	elif (a.rank == 0) != (b.rank == 0):
		share = 0.0 if a.rank == 0 else 1.0
	elif a.wide != b.wide:
		share = 0.0 if a.wide else 1.0
	need -= _push_display(a, side, need * share)
	need -= _push_display(b, -side, need)
	if need > 0.25:
		_push_display(a, side, need)
	var delta := a.position + a.travel - b.position - b.travel
	if same_side and not a.display_passing and not b.display_passing and delta.length_squared() < feet * feet:
		var depth := delta.y if absf(delta.y) > 0.01 else a.layout_pos.y - b.layout_pos.y
		var direction := -1.0 if depth < 0.0 else 1.0
		var wanted := sqrt(maxf(0.0, feet * feet - delta.x * delta.x)) - absf(delta.y)
		var moved := _push_depth(a, direction, wanted * 0.5)
		moved += _push_depth(b, -direction, wanted - moved)
		_push_depth(a, direction, wanted - moved)


func _push_depth(f: Fighter, direction: float, amount: float) -> float:
	if f.step_limit == 0.0 or amount <= 0.0:
		return 0.0
	var vertical := sqrt(maxf(0.0, f.step_limit * f.step_limit - f.travel.x * f.travel.x))
	var room := minf(vertical, _trail_depth - f.position.y * direction) - f.travel.y * direction
	var pushed := clampf(room, 0.0, amount)
	f.travel.y += direction * pushed
	f.display_corrected = f.display_corrected or pushed > 0.0
	return pushed


func _push_display(f: Fighter, side: float, amount: float) -> float:
	if f.step_limit == 0.0 or amount <= 0.0:
		return 0.0
	var horizontal := sqrt(maxf(0.0, f.step_limit * f.step_limit - f.travel.y * f.travel.y))
	var edge := (_field_bounds.end.x - f.end_x if side > 0.0 else f.outline.position.x - _field_bounds.position.x) - 12.0
	var room := minf(horizontal, edge - f.position.x * side) - f.travel.x * side
	var pushed := clampf(room, 0.0, amount)
	f.travel.x += side * pushed
	f.display_corrected = f.display_corrected or pushed > 0.0
	return pushed


func _face_and_strike(gdt: float) -> void:
	for f in _fighters:
		if not f.unit.alive:
			continue
		f.face_hold = maxf(0.0, f.face_hold - gdt)
		var target := f.layout_target
		if f.aim_target != null and f.aim_target.alive:
			target = views.get(f.aim_target.id)
		if (f.strike_wait > 0.0 or f.strike_hold > 0.0) and is_instance_valid(f.strike_target):
			target = f.strike_target
		if target != null and (not _front_active or f.rear or f.pass_phase == Pass.REAR):
			f.aim_at(target, true)
		else:
			f.aim_depth = 0.0
			if target != null and f.long_model.is_empty():
				f.aim_depth = clampf((target.position.y - f.position.y) * 0.23, -13.0, 13.0)
			f.face_stable(f.side_dir > 0.0)
		f.update_outline()

	for f in _fighters:
		if not f.unit.alive or f.rear:
			continue
		var target := f.strike_target
		var contact := is_instance_valid(target) and f.can_strike(target)
		var striking := f.attack_left > 0.0 or (f.sprite != null and f.sprite.animation == &"attack" and f.sprite.is_playing())
		if striking and not contact:
			f.attack_left = 0.0
			f.strike_hold = 0.0
			if f.sprite == null:
				f.clip = f.idle_clip
			else:
				f.sprite.play(&"idle")
		if f.strike_wait <= 0.0:
			continue
		if contact and _may_strike(f):
			_play_strike(f, target)
		else:
			f.strike_wait = maxf(0.0, f.strike_wait - gdt)


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
		var interval_layout := 1.0 / (30.0 if _fighters.size() > 20 else 60.0)
		if _layout_time >= interval_layout or _spawn_layout:
			_spawn_layout = false
			var layout_started := Time.get_ticks_usec() if profile_display else 0
			if _layout_step != sim.steps:
				_plan_layout(_layout_sim_time)
				_layout_step = sim.steps
			for f in _fighters:
				if f.unit.alive and f.spawn_pending:
					f.spawn_pending = false
					f.position = f.layout_pos
					f.drawn_foot = f.position
			_layout_time = fposmod(_layout_time, interval_layout)
			_layout_sim_time = 0.0
			if layout_started != 0:
				layout_usec += Time.get_ticks_usec() - layout_started
		_advance_display(gdt)
		_face_and_strike(gdt)
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
		if legacy_layout or refresh_people:
			_place_actor(f, rate, false, f.release_frame == Engine.get_process_frames())
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
	_display_order.clear()
	_raiders.clear()
	_ally_line.reset(0.0)
	_enemy_line.reset(0.0)
	_front_active = false
	_front_x = 0.0
	_front_goal = 0.0
	_arrival_order = 0
	melee_requests = 0
	melee_played = 0
	_spawn_layout = false
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


class FrontLine:
	var side: float
	var edge := 0.0
	var lead: Fighter
	var front: Array[Fighter] = []
	var melee: Array[Fighter] = []
	var entering: Array[Fighter] = []
	var rear: Array[Fighter] = []
	var front_mask := 0
	var tails: Array[Fighter] = [null, null, null, null, null]
	var edges := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var room := 0.0
	var front_room := 0.0
	var back := 0.0
	var back_center := 0.0

	func _init(direction: float) -> void:
		side = direction

	func reset(field_edge: float) -> void:
		edge = field_edge
		lead = null
		front.clear()
		front_mask = 0
		melee.clear()
		entering.clear()
		rear.clear()
		tails.fill(null)
		edges.fill(0.0)
		room = 0.0
		front_room = 0.0
		back = 0.0
		back_center = 0.0


class Fighter extends Node2D:
	var unit: LegionSim.Unit
	var view: LegionBattleView
	var side_dir := 1.0
	var rear := false
	var rear_mount := false
	var turn_radius := 0.0
	var goal := Vector2.ZERO
	var layout_pos := Vector2.ZERO
	var follow_velocity := Vector2.ZERO
	var step_limit := 0.0
	var sweep_left := 0.0
	var display_corrected := false
	var travel := Vector2.ZERO
	var display_passing := false
	var drawn_foot := Vector2.ZERO
	var spawn_pending := true
	var body_half := 25.0
	var muzzle := 25.0
	var rump := 25.0
	var beam := 50.0
	var strike_distance := 55.0
	var aim_depth := 0.0
	var outline := Rect2()
	var hull_points := PackedVector3Array()
	var hull_angle := INF
	var _outline_scale := -1.0
	var _outline_pose: StringName
	var hud_anchor := Vector2.ZERO
	var outline_area := 0.0
	var end_x := 0.0
	var layout_target: Fighter
	var strike_target: Fighter
	var strike_wait := 0.0
	var arrival_order := 0
	var front_row := -1
	var row_mask := 0
	var rank := -1
	var was_front := false
	var duel_with := -1
	var duel_weight := 0.0
	var incoming := 0
	var front_attackers := 0
	var front_guard := false
	var queue_ahead: Fighter
	var pass_phase := Pass.NONE
	var pass_lane := 0.0
	var strike_action := ""
	var strike_hold := 0.0
	var sheet := ""
	var silhouette := Vector2.ZERO
	var health := 1.0
	var flash := 0.0
	var death := 0.0
	var status_color := Color.TRANSPARENT
	var sprite: AnimatedSprite2D
	var actor: Actor
	var flip_h := false
	var face_hold := 0.0
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

	func face_stable(left: bool) -> void:
		if left != flip_h and face_hold <= 0.0:
			face(left)
			face_hold = FACE_HOLD

	func measure_body() -> void:
		side_dir = -1.0 if unit.side == "ally" else 1.0
		rear = unit.ranged() or unit.heal_pow > 0.0
		rear_mount = rear and wide and not long_model.is_empty()
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
		end_x = outline.end.x

	func screen_box() -> Rect2:
		var scale_ui := view.world.scale
		return Rect2(view.screen(visible_foot() + outline.position), outline.size * scale_ui)

	func body_width() -> float:
		return body_half * 2.0

	func move_speed() -> float:
		var stride := 2.45 if wide or unit.key in ["cavalry", "boar"] else clampf(unit.speed * 1.20, 1.50, 2.00)
		# 66 ???????? ?? ????. ??? ????? ????? ???? ? 1,4 ???? ???????.
		var sim_speed := unit.speed * 66.0 * maxf(1.4, unit.horn_k)
		return maxf(body_width() * stride, sim_speed / 1.30)

	func rear_spacing() -> float:
		return maxf(beam * 2.80, 154.0)

	func edge_toward(dir: float) -> float:
		if rear_mount or (wide and long_model.is_empty() and not hull_points.is_empty()):
			return -outline.position.x if dir < 0.0 else outline.end.x
		return muzzle if (dir < 0.0) == flip_h else rump

	func on_own_side() -> bool:
		return pass_phase == Pass.NONE or pass_phase == Pass.APPROACH

	func front_clearance() -> float:
		return strike_distance * (0.39 if long_model.is_empty() else 0.04)

	func neighbouring_row(target: Fighter) -> bool:
		var adjacent := row_mask | (row_mask << 1) | (row_mask >> 1)
		return (adjacent & target.row_mask) != 0

	func can_strike(target: Fighter) -> bool:
		var d := target.body_ground() - body_ground()
		var source_edge := edge_toward(d.x) if wide and long_model.is_empty() else muzzle
		var depth := d.y
		if view != null and not view.legacy_layout and rank == 0 and target.rank == 0:
			# Удар в соседний ряд идёт по диагонали в глубину сцены.
			depth *= STRIKE_DEPTH
			if not neighbouring_row(target) and absf(d.y) > view._row_extent + 1.0:
				return false
		var gap := Vector2(maxf(0.0, absf(d.x) - source_edge - target.edge_toward(-d.x)), depth)
		if gap.length_squared() > strike_distance * strike_distance or flip_h != (d.x < 0.0):
			return false
		if view == null or view.legacy_layout:
			return true
		var relative_box := Rect2(outline.position - d, outline.size)
		var shared := relative_box.intersection(target.outline).get_area()
		return shared <= minf(outline_area, target.outline_area) * 0.29

	func aim_at(target: Fighter, stable := false) -> void:
		var d := target.body_ground() - body_ground()
		if not stable:
			face(d.x < 0.0)
		elif absf(d.x) >= 4.0:
			face_stable(d.x < 0.0)
		# Нос длинной модели должен оставаться на рассчитанной границе.
		aim_depth = clampf(d.y * 0.23, -13.0, 13.0) if long_model.is_empty() else 0.0

	func layout_point(x: float, z: float) -> Vector2:
		if view != null and not view.legacy_layout:
			var depth := clampf(lerpf(lane_z, z, 0.30) * 29.0, -view._trail_depth, view._trail_depth)
			var sx := clampf(x * 66.0, -box_limit(), box_limit())
			if rear:
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
		follow_velocity = Vector2.ZERO
		strike_hold = 0.0
		strike_wait = 0.0
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
		var follows_layout := view != null and not view.legacy_layout
		var walking := travel.length_squared() > (gdt * body_width() * 0.055) ** 2 and gdt > 0.0 and fighting
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
		if walking and follows_layout:
			walk_rate = travel.length() / (gdt * body_width() * 1.65)
		if boss_model != null:
			boss_model.moving = walking
			var direction := -1.0 if flip_h else 1.0
			var distance := travel.length() if follows_layout else dx * direction
			boss_model.roll(distance * 1.79 / (model_height() * sin(deg_to_rad(yaw))))
		if sprite != null:
			if (follows_layout and walking and strike_hold <= 0.0) or sprite.animation != &"attack" or not sprite.is_playing():
				sprite.play(&"walk" if walking else &"idle")
			sprite.speed_scale = rate * (walk_rate if sprite.animation == &"walk" else 1.0)
		elif follows_layout and walking and strike_hold <= 0.0 and (not rear or (not ranged_winding and attack_left <= 0.0)):
			sample = sample + gdt * walk_rate if clip == walk_clip else 0.0
			clip = walk_clip
			hit_left = 0.0
			attack_left = 0.0
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
