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
const TRAIL_DEPTH := [48.0, 51.0, 54.0, 61.0]

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
const LAYOUT_FRAME := 1.0 / 60.0
const WALK_THRESHOLD := 0.055
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
var _mounted_line_edge := INF
var _mounted_front_min := -INF
var _layout_step := -1
var _layout_time := 0.0
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
		if not f.rear:
			f.front_limit = REAR_X - 185.0
		f.position = _spawn_foot(f, f.position)
		f.next_foot = f.position
	_place_actor(f)
	views[u.id] = f
	_fighters.append(f)
	_layout_step = -1
	if not legacy_layout and f.mounted_line:
		# Расставляем подкрепление и обновляем 3D-слой в том же кадре.
		_layout_time = LAYOUT_FRAME
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
	if legacy_layout:
		source.attack(action)
		melee_pose.emit(source, target)
		return
	source.pending_target = target
	source.pending_until = -1.0
	source.strike_action = action
	_layout_step = -1


func _fit_foot(f: Fighter, pos: Vector2) -> Vector2:
	var limits := _foot_limits(f)
	return Vector2(clampf(pos.x, limits.x, limits.y), clampf(pos.y, -_trail_depth, _trail_depth))


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



func _spawn_foot(f: Fighter, at: Vector2) -> Vector2:
	if f.rear_mount:
		var edge := _field_bounds.end.x - 12.0
		for other in _fighters:
			if other.rear_mount and other.unit.alive:
				edge = minf(edge, other.position.x + other.outline.position.x - 18.0)
		return _fit_foot(f, Vector2(edge - f.outline.end.x, at.y))
	var foot := _fit_foot(f, at)
	if _spawn_clear(f, foot):
		return foot
	var stride := f.body_width() * 0.72
	for row in range(4):
		for lane: int in [0, 1, -1, 2, -2]:
			var offset := Vector2(f.side_dir * row, lane) * stride
			if f.unit.entering:
				offset.x *= -f.unit.enter_dir * f.side_dir
			var candidate := _fit_foot(f, foot + offset)
			if _spawn_clear(f, candidate):
				return candidate
	return foot


func _spawn_clear(f: Fighter, at: Vector2) -> bool:
	for other in _fighters:
		if other.unit.alive:
			var gap := minf(f.body_half, other.body_half) * 1.10
			if at.distance_squared_to(other.position) < gap * gap:
				return false
			if f.side_dir == other.side_dir:
				var common := Rect2(f.outline.position + at - other.position, f.outline.size).intersection(other.outline)
				if common.get_area() > minf(f.outline_area, other.outline_area) * 0.22:
					return false
	return true


func _plan_layout(now: float) -> void:
	var started := Perf13.begin()
	_plan_layout_profiled(now)
	Perf13.end(Perf13.PLAN, started)


func _plan_layout_profiled(now: float) -> void:
	var ally_rear := INF
	var enemy_rear := INF
	var mount_edge := _field_bounds.end.x - 12.0
	_mounted_front_min = -INF
	for f in _fighters:
		f.approachers.clear()
		f.primary_attacker = null
		f.contact_front = null
		f.visit = 0
		f.contact_blend = 0.0
		if not f.unit.alive:
			f.layout_target = null
			f.slot = 0
			continue
		if not f.rear:
			continue
		var u := f.unit
		f.goal = _fit_foot(f, f.layout_point(u.x, u.z))
		if f.rear_mount:
			f.goal.x = mount_edge - f.outline.end.x
			f.goal = _fit_foot(f, f.goal)
			mount_edge = f.goal.x + f.outline.position.x - 18.0
			_mounted_front_min = maxf(0.0, mount_edge - 215.0)
		var gate := minf(f.goal.x * f.side_dir, f.position.x * f.side_dir) - f.rear_spacing()
		if f.side_dir < 0.0:
			ally_rear = minf(ally_rear, gate)
		else:
			enemy_rear = minf(enemy_rear, gate)
	for f in _fighters:
		if not f.unit.alive or f.rear:
			continue
		var u := f.unit
		f.front_limit = ally_rear if f.side_dir < 0.0 else enemy_rear
		f.goal = _fit_foot(f, f.layout_point(u.x, u.z))
		var target: Fighter = views.get(u.target.id) if u.target != null and u.target.alive else null
		var previous := f.layout_target
		var pending := f.pending_target
		if is_instance_valid(pending) and pending.unit.alive:
			target = pending
		elif f.is_striking() and is_instance_valid(f.strike_target) and f.strike_target.unit.alive:
			target = f.strike_target
		elif is_instance_valid(previous) and previous.unit.alive and target != previous:
			var reach := u.range_m + 0.35 * (u.size + previous.unit.size - 2.0)
			if LegionSim.dist(u, previous.unit) <= reach + 2.1:
				target = previous
		if u.entering:
			target = null
		if target != null:
			var reach := u.range_m + 0.35 * (u.size + target.unit.size - 2.0)
			f.contact_blend = 1.0 - smoothstep(reach + 1.3, reach + 3.4, LegionSim.dist(u, target.unit))
			if target == previous or target == pending:
				f.contact_blend = 1.0
			if f.contact_blend <= 0.0:
				target = null
		if target != previous:
			f.slot = 0
			f.bypass = null
			f.flank_reached = false
			f.approach_side = f.side_dir if u.enter_dir < 0.0 else -1.0
			if target != null:
				var dx := f.position.x - target.position.x
				if absf(dx) >= target.body_half * 0.5:
					f.approach_side = signf(dx)
				if not target.long_model.is_empty() and not target.rear_mount and not f.wide:
					f.approach_side = -target.side_dir if target.unit.enter_dir < 0.0 else 1.0
		if target != null and target == pending and f.pending_until < 0.0:
			f.pending_until = now + 1.30
		f.layout_target = target
		if target != null:
			target.approachers.append(f)

	for target in _fighters:
		if not target.approachers.is_empty():
			if target.approachers.size() >= 2:
				target.goal.y = clampf(target.goal.y, -_trail_depth + 35.0, _trail_depth - 35.0)
			_reserve_spots(target)
	for f in _fighters:
		var target := f.layout_target
		if f.holds_front() and not f.rear:
			f.goal = _fit_foot(f, f.position)
			f.visit = 2
		if f.visit != 0 or not f.unit.alive or target == null or target.layout_target != f:
			continue
		if target.holds_front() or target.visit != 0:
			continue
		if f.slot != 1 or target.slot != 1 or f.spot_side == target.spot_side:
			continue
		# Взаимная пара встречается посередине между исходными местами.
		var center := (f.goal + target.goal) * 0.5
		center.y = clampf(center.y, -_trail_depth * 0.30, _trail_depth * 0.30)
		var dir := f.spot_side
		var clearance := minf(f.front_clearance(), target.front_clearance())
		if f.long_model.is_empty() and target.long_model.is_empty() and (f.approachers.size() > 1 or target.approachers.size() > 1):
			clearance = minf(f.strike_distance, target.strike_distance) * 0.78
		var gap := f.front_edge(-dir) + target.front_edge(dir) + clearance
		var blend := minf(f.contact_blend, target.contact_blend)
		f.goal = f.goal.lerp(_fit_foot(f, center + Vector2(dir * gap * 0.5, 0.0)), blend)
		target.goal = target.goal.lerp(_fit_foot(target, center - Vector2(dir * gap * 0.5, 0.0)), blend)
		f.visit = 2
		target.visit = 2
	for f in _fighters:
		if f.unit.alive:
			_engagement_goal(f)


func _reserve_spots(target: Fighter) -> void:
	var used := 0
	var leader: Fighter
	for f in target.approachers:
		if f.slot == 1:
			leader = f
		if f.slot > 0 and f.slot < 4:
			used |= 1 << f.slot
	# У строя спереди нужна морда длинной модели, а не её бок.
	if leader != null and leader.long_model.is_empty() and target.long_model.is_empty():
		for f in target.approachers:
			if not f.long_model.is_empty() and f.pending_target == target and f.approach_side == f.side_dir:
				leader.slot = f.slot
				leader.flank_reached = false
				if leader.slot == 2 and not leader.wide and not target.wide:
					leader.spot_side = -leader.approach_side
				f.slot = 1
				f.spot_side = f.approach_side
				f.flank_reached = false
				break
	for slot_id: int in [1, 3, 2]:
		if used & (1 << slot_id):
			continue
		var nearest: Fighter
		var best := INF
		for f in target.approachers:
			if f.slot > 0 and f.slot < 4:
				continue
			if slot_id == 2 and (f.wide or target.wide) and target.approachers.size() > 3:
				continue
			var cost := f.position.distance_squared_to(target.position)
			if f.pending_target == target:
				cost -= 80000.0
			if slot_id == 1:
				if target.layout_target == f:
					cost -= 120000.0
				if not f.long_model.is_empty() and target.long_model.is_empty():
					cost -= 240000.0
			if cost < best:
				nearest = f
				best = cost
		if nearest == null:
			break
		nearest.slot = slot_id
		nearest.flank_reached = false
		nearest.spot_side = nearest.approach_side
		if slot_id == 2 and not nearest.wide and not target.wide:
			nearest.spot_side = -nearest.approach_side
		if slot_id in [2, 3]:
			var room := _trail_depth - 35.0
			nearest.flank_depth = -1.0 if target.position.y > room or (target.position.y >= -room and
				nearest.position.y < target.position.y) else 1.0
	var queue := 0
	for f in target.approachers:
		if f.slot == 1:
			target.primary_attacker = f
			if not f.long_model.is_empty() and target.long_model.is_empty():
				target.contact_front = f
		elif f.slot == 0 or f.slot >= 4:
			f.slot = 4 + queue
			f.spot_side = f.approach_side
			queue += 1



func _spot(f: Fighter, target: Fighter, at: Vector2, slot: int) -> Vector2:
	var dir := f.spot_side
	var our_long := f.wide
	var their_long := target.wide
	var depth := at.y
	var source_edge := f.front_edge(-dir)
	var space := f.front_clearance()
	if their_long and not our_long:
		space = 8.0 if target.approachers.size() < 2 else f.strike_distance * 0.68
	elif slot == 1 and not our_long and target.approachers.size() > 1:
		space = f.strike_distance * 0.75
	if slot == 2 or slot == 3:
		var lane := f.flank_depth
		if f.spot_side == f.approach_side and slot == 2:
			lane = -lane
		var height := minf(43.0, f.strike_distance * 0.78)
		if lane * at.y > _trail_depth - height:
			lane = -lane
		depth += lane * height
		if not f.long_model.is_empty():
			space = f.front_clearance()
		elif f.spot_side != f.approach_side:
			space *= 0.64
		else:
			space = 1.0
	elif slot >= 4:
		space += maxf(64.0, f.body_width()) * float(slot - 3)
		depth += (-1.0 if slot % 2 == 0 else 1.0) * _trail_depth * 0.78
	var at_nose := not target.long_model.is_empty() and not target.rear_mount and not our_long
	var target_edge := target.front_edge(dir) if at_nose else target.edge_toward(dir)
	return _fit_foot(f, Vector2(at.x + dir * (source_edge + target_edge + space), depth))


func _engagement_goal(f: Fighter) -> void:
	var started := Perf13.begin()
	_engagement_goal_profiled(f)
	Perf13.end(Perf13.GOAL, started)


func _engagement_goal_profiled(f: Fighter) -> void:
	if f.visit != 0:
		return
	f.visit = 1
	var target := f.layout_target
	if target != null:
		# Крупный боец подходит к текущей линии. Идущие следом учитывают её ближайший шаг.
		var at := target.position
		if target.visit == 2 and target.contact_front == null and f.long_model.is_empty():
			at += (target.goal - at).limit_length(f.body_width() * 0.25)
		f.goal = f.goal.lerp(_spot(f, target, at, f.slot), f.contact_blend)
	f.visit = 2



func _layout() -> void:
	_wide_fighters.clear()
	for f in _fighters:
		if not f.unit.alive:
			continue
		var goal := f.goal
		var front := f.contact_front
		if front != null and front.unit.alive and not f.holds_front():
			var dir := front.spot_side
			var x := front.goal.x - dir * (front.muzzle + f.edge_toward(dir) + front.front_clearance())
			goal.x = lerpf(goal.x, x, front.contact_blend)
			if f.layout_target == front:
				goal.y = lerpf(goal.y, front.goal.y, front.contact_blend * 0.65)
		f.passing = false
		f.next_foot = _around(f, goal) if not f.wide and not f.rear else _fit_foot(f, goal)
		if f.wide:
			_wide_fighters.append(f)
	_space_wide()
	_fit_mounted_line()
	_separate()
	for f in _fighters:
		if f.unit.alive and f.separation_push != Vector2.ZERO:
			# Скорость ограничивается после того, как места разнесены в проекции.
			f.next_foot = _fit_foot(f, f.next_foot + f.separation_push)


func _advance_layout(dt: float, now: float) -> bool:
	var moved := false
	for f in _fighters:
		if not f.unit.alive:
			continue
		var speed := f.move_speed()
		var target := f.layout_target
		var strike := f.strike_target if is_instance_valid(f.strike_target) else null
		var pending := f.pending_target if is_instance_valid(f.pending_target) else null
		var striking := f.is_striking() and not f.rear
		var brace := striking and strike != null and f.can_strike(strike)
		var ready := pending != null and not f.passing and f.can_strike(pending)
		if ready and (not f.needs_front_contact() or f.touches_front(pending)):
			brace = true
		if not f.passing and f.slot in [1, 2, 3] and target != null and target.unit.alive:
			var front := f.contact_front
			var line_ready := front == null or front.touches_front(f)
			var nose_ready := f.long_model.is_empty() or f.touches_front(target)
			var slot_ready := f.slot == 1 or f.next_foot.distance_squared_to(f.position) <= (f.body_width() * 0.30) ** 2
			brace = brace or (line_ready and nose_ready and slot_ready and f.can_strike(target))
		var offset := f.next_foot - f.position
		if brace:
			offset = f.separation_push
		var distance := offset.length()
		var slack := f.body_width() * (0.15 if ready or striking else (0.09 if brace else 0.043))
		if not brace and (f.contact_front != null or not f.long_model.is_empty()):
			slack = 0.9
		var accel := speed * 6.5
		var wanted := Vector2.ZERO
		if distance > slack:
			var pace := minf(speed, minf((distance - slack) * 4.5, sqrt(2.0 * accel * (distance - slack))))
			wanted = offset * (pace / distance)
		if f.unit.entering and wanted.x * f.unit.enter_dir < 0.0:
			wanted.x = 0.0
		if f.velocity.dot(wanted) < 0.0:
			wanted = Vector2.ZERO
		f.velocity = f.velocity.move_toward(wanted, accel * dt)
		if f.velocity.length_squared() <= (f.body_width() * WALK_THRESHOLD) ** 2:
			f.velocity = Vector2.ZERO
		var step := f.velocity * dt
		step.y = clampf(step.y, minf(0.0, -_trail_depth - f.position.y), maxf(0.0, _trail_depth - f.position.y))
		f.travel = step
	_bound_crossings()
	for f in _fighters:
		if not f.unit.alive:
			continue
		if f.travel.length_squared() <= (f.body_width() * WALK_THRESHOLD * dt) ** 2:
			f.travel = Vector2.ZERO
		f.velocity = f.travel / dt
		f.position += f.travel
		moved = moved or f.travel != Vector2.ZERO
	for f in _fighters:
		if not f.unit.alive:
			continue
		var u := f.unit
		var target := f.layout_target
		if f.rear:
			var aim := f.aim_target if f.aim_target != null and f.aim_target.alive else u.target
			target = views.get(aim.id) if aim != null and aim.alive else null
		if f.travel != Vector2.ZERO:
			f.aim_walk(dt)
		elif not u.entering:
			var pending := f.pending_target
			if is_instance_valid(pending):
				f.aim_at(pending)
			elif is_instance_valid(target):
				f.aim_at(target)
			else:
				f.aim_depth = 0.0
				f.face(f.side_dir > 0.0)
		else:
			f.aim_depth = 0.0
			f.face(u.enter_dir < 0.0)
		f.update_outline()
	for f in _fighters:
		if not f.unit.alive or f.rear:
			continue
		var strike := f.strike_target if is_instance_valid(f.strike_target) else null
		if f.is_striking() and (strike == null or not f.can_strike(strike) or f.travel != Vector2.ZERO):
			f.stop_strike()
		var pending := f.pending_target if is_instance_valid(f.pending_target) else null
		if pending != null:
			var in_reach := f.can_strike(pending) and (not f.needs_front_contact() or f.touches_front(pending))
			if f.travel == Vector2.ZERO and not f.passing and in_reach:
				f.strike_target = pending
				f.pending_target = null
				f.attack(f.strike_action)
				melee_pose.emit(f, pending)
			elif not pending.unit.alive or now > f.pending_until:
				f.pending_target = null
	return moved


func _bound_crossings() -> void:
	for f in _fighters:
		var target := f.layout_target
		if not f.unit.alive or target == null or not target.unit.alive:
			continue
		if f.passing and f.bypass == target and f.travel.length_squared() > (f.body_width() * 0.002) ** 2:
			continue
		# Оба шага могут сблизить пару. Оставляем зазор, пока нет обхода.
		var dx := f.position.x - target.position.x
		var gap := maxf(0.0, absf(dx) - 1.5)
		if gap > absf(f.travel.x) + absf(target.travel.x):
			continue
		var side := signf(dx) if not is_zero_approx(dx) else f.spot_side
		var half_gap := gap * 0.48
		if f.travel.x * side < 0.0:
			f.travel.x = signf(f.travel.x) * minf(absf(f.travel.x), half_gap)
		if target.travel.x * side > 0.0:
			target.travel.x = signf(target.travel.x) * minf(absf(target.travel.x), half_gap)


func _around(f: Fighter, goal: Vector2) -> Vector2:
	var from := f.position
	var target := f.layout_target
	# Дальнее место появляется только после двух занятых ближних.
	if f.slot == 2 and not f.flank_reached and is_instance_valid(target) and f.spot_side != f.approach_side:
		var dx := (from.x - target.position.x) * f.spot_side
		var clearance := f.body_half + target.edge_toward(f.spot_side) + 10.0
		if dx < clearance:
			if f.bypass != target:
				f.bypass = target
				f.bypass_lower = target.position.y > 0.0
			var lane_dir := -1.0 if f.bypass_lower else 1.0
			var lane := clampf(target.position.y + lane_dir * 50.0, -_trail_depth, _trail_depth)
			f.passing = absf(from.y - target.position.y) >= 35.0 or dx > 0.0
			var side := f.spot_side if f.passing else f.approach_side
			return _fit_foot(f, Vector2(target.position.x + side * (clearance + 8.0), lane))
		f.flank_reached = true
	f.bypass = null
	return _fit_foot(f, goal)


func _wide_order(f: Fighter) -> float:
	# Колесничий, который ведёт атаку, остаётся впереди второй повозки.
	if f.unit.key == "charioteer":
		return _field_bounds.position.x if f.side_dir > 0.0 else _field_bounds.end.x
	if f.rear_mount:
		return _field_bounds.end.x + _field_bounds.size.x * 2.0 - float(f.unit.id)
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
		b.next_foot = _fit_foot(b, Vector2(maxf(b.next_foot.x, a.next_foot.x + gap), b.next_foot.y))
	for i in range(_wide_fighters.size() - 2, -1, -1):
		var a := _wide_fighters[i]
		var b := _wide_fighters[i + 1]
		var gap := _wide_gap(a, b)
		a.next_foot = _fit_foot(a, Vector2(minf(a.next_foot.x, b.next_foot.x - gap), a.next_foot.y))


func _wide_gap(a: Fighter, b: Fighter) -> float:
	var min_width := minf(a.body_width(), b.body_width())
	var edges := a.outline.end.x - b.outline.position.x
	if a.rear_mount or b.rear_mount:
		return edges + 12.0
	var overlap := minf(a.outline.size.x, b.outline.size.x) * (0.36 if _wide_fighters.size() > 2 else 0.23)
	return clampf(edges - overlap, min_width * 0.57, min_width * 0.94)



func _fit_mounted_line() -> void:
	_mounted_line_edge = INF
	for f in _wide_fighters:
		if f.rear_mount:
			var nose := minf(f.outline.position.x, -f.outline.end.x)
			_mounted_line_edge = minf(_mounted_line_edge, minf(f.position.x, f.next_foot.x) + nose - 28.0)
	if _mounted_line_edge < INF:
		for f in _fighters:
			if f.unit.alive and f.side_dir < 0.0:
				f.next_foot = _fit_foot(f, f.next_foot)


func _separate() -> void:
	var started := Perf13.begin()
	_separate_profiled()
	Perf13.end(Perf13.SEPARATE, started)


func _separate_profiled() -> void:
	# Пружина задаёт поправку к цели. Позицию меняет только шаг движения.
	for f in _fighters:
		if f.unit.alive:
			f.separation_push = Vector2.ZERO
			f.separation_position = f.next_foot
			f.separation_limits = _foot_limits(f)
			f.separation_priority = f.guard_priority()
	for i in _fighters.size():
		var a := _fighters[i]
		if not a.unit.alive:
			continue
		var box := a.outline
		for j in i:
			var b := _fighters[j]
			if not b.unit.alive:
				continue
			var d := a.separation_position - b.separation_position
			var feet := minf(a.body_half, b.body_half) * 1.36
			var clearance := 12.0 if a.rear_mount or b.rear_mount else 0.0
			var extent := maxf(feet, maxf(b.end_x - box.position.x, a.end_x - b.outline.position.x) + clearance)
			var actual := a.position - b.position
			var walking_around := (a.passing and a.bypass == b or b.passing and b.bypass == a)
			if not walking_around and absf(actual.x) < extent:
				_open_projection(a, b, actual, feet, clearance)
			if absf(d.x) >= extent:
				continue
			var overlap_y := minf(d.y + box.end.y, b.outline.end.y) - maxf(d.y + box.position.y, b.outline.position.y)
			if overlap_y <= 0.0 and absf(d.y) >= feet:
				continue
			var dx := d.x
			var side := signf(dx) if absf(dx) > 0.01 else a.side_dir
			var passing := walking_around and absf(d.y) >= 30.0
			var guard := 0.0
			if not passing:
				if a.layout_target == b:
					guard = a.approach_side if a.bypass == b else a.spot_side
				elif b.layout_target == a:
					guard = -b.approach_side if b.bypass == a else -b.spot_side
			if guard != 0.0:
				side = guard
			var push := sqrt(maxf(0.0, feet * feet - d.y * d.y)) - d.x * side
			if guard != 0.0 and absf(d.y) < feet * 1.35:
				push = maxf(push, feet * 0.62 - d.x * guard)
			if overlap_y > 0.0 and not passing:
				var tolerance := 0.09 if a.side_dir == b.side_dir else (0.10 if a.wide or b.wide else 0.22)
				if a.wide and b.wide and clearance == 0.0:
					tolerance = 0.34
				var permitted := minf(a.outline_area, b.outline_area) * tolerance / overlap_y if clearance == 0.0 else -clearance
				var facing := d.x + a.center_x - b.center_x
				var box_side := signf(facing) if absf(facing) > 0.01 else side
				if a.contact_front == b:
					box_side = -b.spot_side
				elif b.contact_front == a:
					box_side = a.spot_side
				elif guard != 0.0:
					box_side = guard
				var edge := b.end_x - box.position.x if box_side > 0.0 else a.end_x - b.outline.position.x
				var needed := edge - d.x * box_side - permitted
				if needed > push:
					side = box_side
					push = needed
			if push <= 1.0:
				continue
			var share := 0.5
			if a.wide != b.wide:
				share = 0.0 if a.wide else 1.0
			elif a.separation_priority != b.separation_priority:
				share = 0.0 if a.separation_priority > b.separation_priority else 1.0
			elif a.rear != b.rear:
				share = 0.12 if a.rear else 0.88
			var a_room := a.separation_limits.y - a.separation_position.x if side > 0.0 else a.separation_position.x - a.separation_limits.x
			var b_room := b.separation_position.x - b.separation_limits.x if side > 0.0 else b.separation_limits.y - b.separation_position.x
			if a_room < 5.0 and not b.wide:
				share = 0.0
			elif b_room < 5.0 and not a.wide:
				share = 1.0
			# Сдвигаем только места, чтобы следующая пара видела поправку.
			var a_shift := minf(maxf(0.0, a_room), push * share)
			var b_shift := minf(maxf(0.0, b_room), push - a_shift)
			if push > a_shift + b_shift and not a.wide:
				a_shift = minf(maxf(0.0, a_room), push - b_shift)
			a.separation_position.x += a_shift * side
			b.separation_position.x -= b_shift * side
	for f in _fighters:
		if f.unit.alive:
			f.next_foot = f.separation_position


func _open_projection(a: Fighter, b: Fighter, d: Vector2, feet: float, clearance: float) -> void:
	var box := a.outline
	var other := b.outline
	var same_side := a.side_dir == b.side_dir
	var dy := minf(d.y + box.end.y, other.end.y) - maxf(d.y + box.position.y, other.position.y)
	var projected := d.x + a.center_x - b.center_x
	var order := signf(projected) if absf(projected) > 1.0 else a.side_dir
	if a.contact_front == b:
		order = -b.spot_side
	elif b.contact_front == a:
		order = a.spot_side
	var gap := 0.0
	if dy > 0.0:
		var allowed := (0.12 if same_side or a.wide or b.wide else 0.23) * minf(a.outline_area, b.outline_area) / dy
		if a.wide and b.wide and clearance == 0.0:
			allowed *= 2.8
		var edge := b.end_x - box.position.x if order > 0.0 else a.end_x - other.position.x
		gap = edge - d.x * order - (allowed if clearance == 0.0 else -clearance)
	if absf(d.x) < feet and absf(d.y) < feet:
		gap = maxf(gap, sqrt(maxf(0.0, feet * feet - d.y * d.y)) - absf(d.x))
	if gap < 0.8:
		return
	var share := 0.5
	if a.wide != b.wide:
		share = 0.0 if a.wide else 1.0
	elif a.separation_priority != b.separation_priority:
		share = 0.0 if a.separation_priority > b.separation_priority else 1.0
	elif a.rear != b.rear:
		share = 0.0 if a.rear else 1.0
	var a_room := a.separation_limits.y - a.position.x if order > 0.0 else a.position.x - a.separation_limits.x
	var b_room := b.position.x - b.separation_limits.x if order > 0.0 else b.separation_limits.y - b.position.x
	if a_room < gap * 0.4 and not b.rear_mount:
		share = 0.0
	elif b_room < gap * 0.4 and not a.rear_mount:
		share = 1.0
	var push := minf(gap * 3.2, feet * 2.5) * order
	a.separation_push.x += push * share
	b.separation_push.x -= push * (1.0 - share)
	if same_side and absf(d.x) < feet * 0.58 and absf(d.y) < feet:
		_step_aside(a, b, d, feet)


func _step_aside(a: Fighter, b: Fighter, d: Vector2, feet: float) -> void:
	var gap := sqrt(maxf(0.0, feet * feet - d.x * d.x)) - absf(d.y)
	var direction := signf(d.y) if absf(d.y) > 1.0 else (-1.0 if a.lane_z < b.lane_z else 1.0)
	var share := 0.0 if a.wide else (1.0 if b.wide else 0.5)
	if absf(a.position.y + direction * gap) > _trail_depth and not b.wide:
		share = 0.0
	elif absf(b.position.y - direction * gap) > _trail_depth and not a.wide:
		share = 1.0
	a.separation_push.y += gap * 2.0 * direction * share
	b.separation_push.y -= gap * 2.0 * direction * (1.0 - share)


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
	if not legacy_layout and gdt > 0.0:
		_layout_time += dt
		if _layout_time + 0.000001 >= LAYOUT_FRAME or _layout_step < 0:
			if _layout_step != sim.steps:
				_plan_layout(sim.t)
				_layout_step = sim.steps
				_layout()
			_layout_time = fposmod(_layout_time + 0.000001, LAYOUT_FRAME)
		if _advance_layout(gdt, sim.t) and not refresh_people:
			refresh_people = true
			people_layer.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
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
			var released := f.release_frame == Engine.get_process_frames()
			if not released or not legacy_layout:
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
	var drawn_foot := Vector2.ZERO
	var velocity := Vector2.ZERO
	var approach_side := 1.0
	var spot_side := 1.0
	var flank_depth := 1.0
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
	var separation_push := Vector2.ZERO
	var bypass: Fighter
	var bypass_lower := false
	var flank_reached := false
	var passing := false
	var next_foot := Vector2.ZERO
	var layout_target: Fighter
	var contact_front: Fighter
	var strike_target: Fighter
	var pending_target: Fighter
	var pending_until := -1.0
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


	func move_speed() -> float:
		var speed := clampf(unit.speed * 1.20, 1.50, 2.00)
		if wide or unit.key in ["cavalry", "boar"]:
			speed = 2.45
		return body_width() * speed

	func is_striking() -> bool:
		return attack_left > 0.0 or (sprite != null and sprite.animation == &"attack" and sprite.is_playing())

	func stop_strike() -> void:
		attack_left = 0.0
		if sprite == null:
			clip = idle_clip
		else:
			sprite.play(&"idle")


	func screen_box() -> Rect2:
		var scale_ui := view.world.scale
		return Rect2(view.screen(visible_foot() + outline.position), outline.size * scale_ui)

	func body_width() -> float:
		return body_half * 2.0

	func rear_spacing() -> float:
		return maxf(beam * (2.15 if rear_mount else 2.90), 164.0)

	func guard_priority() -> int:
		if contact_front == null:
			return 0
		return 2 if contact_front.unit.key == "charioteer" else 1

	func holds_chariot() -> bool:
		return guard_priority() == 2 and contact_front.contact_blend >= 0.95

	func holds_front() -> bool:
		return contact_front != null and contact_front.needs_front_contact() and contact_front.contact_blend >= 0.95

	func needs_front_contact() -> bool:
		return unit.key == "charioteer" or unit.key == "elephant"

	func edge_toward(dir: float) -> float:
		if rear_mount or (wide and long_model.is_empty() and not hull_points.is_empty()):
			return -outline.position.x if dir < 0.0 else outline.end.x
		return muzzle if (dir < 0.0) == flip_h else rump

	func front_edge(dir: float) -> float:
		return edge_toward(dir) if wide and long_model.is_empty() else muzzle

	func front_clearance() -> float:
		return strike_distance * 0.58 if long_model.is_empty() else 4.0

	func touches_front(target: Fighter) -> bool:
		var d := target.position - position
		var gap := absf(d.x) - muzzle - target.edge_toward(-d.x)
		return absf(gap) <= target.body_width() * 0.12 and absf(d.y) < strike_distance

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
				return separated and absf(delta.y) >= 28.0 and absf(d.y) >= 25.0
		return true

	func aim_walk(dt: float) -> void:
		if absf(velocity.x) > maxf(body_width() * 0.30, absf(velocity.y) * 0.43):
			face(velocity.x < 0.0)
		var pitch := clampf(velocity.normalized().y * 22.0, -22.0, 22.0)
		aim_depth = move_toward(aim_depth, pitch, dt * 135.0) if long_model.is_empty() else 0.0

	func aim_at(target: Fighter) -> void:
		var d := target.body_ground() - body_ground()
		if view == null or view.legacy_layout or absf(d.x) > target.body_width() * 0.07:
			face(d.x < 0.0)
		# Нос длинной модели должен оставаться на рассчитанной границе.
		aim_depth = clampf(d.y * 0.23, -13.0, 13.0) if long_model.is_empty() else 0.0

	func layout_point(x: float, z: float) -> Vector2:
		if view != null and not view.legacy_layout:
			var depth := clampf(lerpf(lane_z, z, 0.30) * 23.0, -view._trail_depth, view._trail_depth)
			var sx := clampf(x * 66.0 + clampf(lane_z, -2.0, 2.0) * 31.0, -box_limit(), box_limit())
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
		if actor != null and not hit_clip.is_empty() and unit.alive and attack_left <= 0.0:
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
		var dx := travel.x if gdt > 0.0 else 0.0
		var walking := gdt > 0.0 and travel != Vector2.ZERO
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
		if walking and view != null and not view.legacy_layout:
			walk_rate = velocity.length() / (body_width() * 1.65)
		if boss_model != null:
			boss_model.moving = walking
			var direction := -1.0 if flip_h else 1.0
			var roll_step := walking and view != null and not view.legacy_layout
			var distance := travel.length() if roll_step else dx * direction
			boss_model.roll(distance * 1.79 / (model_height() * sin(deg_to_rad(yaw))))
		if sprite != null:
			if walking or sprite.animation != &"attack" or not sprite.is_playing():
				sprite.play(&"walk" if walking else &"idle")
			sprite.speed_scale = rate * (walk_rate if sprite.animation == &"walk" else 1.0)
		elif walking and view != null and not view.legacy_layout and release_frame != Engine.get_process_frames():
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
			if view != null and not view.legacy_layout:
				retreat = retreat and not walking
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
