class_name LegionBattleView
extends Control
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
var _layout_step := -1
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
			f.body_half *= ratio
			f.muzzle *= ratio
			f.rump *= ratio
			f.beam *= ratio
			f.strike_distance *= ratio
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
	people_layer.fit(size)
	if not legacy_layout:
		# ?? ????????? ???? ?????? ?????????? ???? ????.
		people_layer.crop_to(Rect2(0.0, world.position.y - world.scale.y * 444.0,
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
	# Листы будущих волн и эффекты подгружаются под занавесом.
	for atlas: String in SILHOUETTE:
		_unit_frames(atlas)
	for kind: String in ["fx_hit", "fx_heal", "fx_arrow"]:
		_effect_frames(kind)
	_stone = load("res://assets/ui/ai/icons/rock.png")
	Enemy.prewarm(waves)


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
	f.measure_body()
	f.position = f.layout_point(u.x, u.z)
	if not legacy_layout:
		f.position = _fit_foot(f, f.position)
	f.face(u.side == "enemy" and (not u.entering or u.enter_dir < 0.0))
	_place_actor(f)
	views[u.id] = f
	_fighters.append(f)
	_layout_step = -1
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
		var started := Time.get_ticks_usec() if profile_poses else 0
		var hz := (15.0 if height < 165.0 else 24.0) / maxf(1.0, rate)
		if force_pose:
			f.actor.pose_at(f.clip, f.sample)
		else:
			f.actor.animate(f.clip, f.sample, f.ranged_mix, hz)
		if started != 0:
			pose_usec += Time.get_ticks_usec() - started
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
	source.strike_target = target
	source.strike_action = action
	source.strike_pending = true
	_layout_step = -1


func _fit_foot(f: Fighter, pos: Vector2) -> Vector2:
	var margin := maxf(f.body_half, f.muzzle) + 23.0
	var left := maxf(_field_bounds.position.x + margin, -f.front_limit) if f.side_dir < 0.0 else _field_bounds.position.x + margin
	var right := minf(_field_bounds.end.x - margin, f.front_limit) if f.side_dir > 0.0 else _field_bounds.end.x - margin
	return Vector2(clampf(pos.x, left, right), clampf(pos.y, -_trail_depth, _trail_depth))


func _plan_layout() -> void:
	# За краями полосы 3D-слой пуст.
	var ally_rear := INF
	var enemy_rear := INF
	for f in _fighters:
		if not f.unit.alive or not f.rear:
			continue
		var u := f.unit
		f.goal = _fit_foot(f, f.layout_point(u.x, u.z))
		var alongside := minf(f.goal.x * f.side_dir, f.position.x * f.side_dir)
		var gate := alongside - f.rear_spacing()
		if f.side_dir < 0.0:
			ally_rear = minf(ally_rear, gate)
		else:
			enemy_rear = minf(enemy_rear, gate)
	for f in _fighters:
		f.front = null
		f.upper = null
		f.lower = null
		f.layout_target = null
		f.slot = 0
		f.visit = 0
		f.contact_blend = 0.0
		if not f.unit.alive:
			f.goal = f.position
			continue
		if not f.rear:
			f.front_limit = ally_rear if f.side_dir < 0.0 else enemy_rear
			f.goal = _fit_foot(f, f.layout_point(f.unit.x, f.unit.z))
	for f in _fighters:
		if not f.unit.alive or f.rear:
			continue
		var u := f.unit
		var target: Fighter = views.get(u.target.id) if u.target != null and u.target.alive else null
		var in_pose := f.attack_left > 0.0 or (f.sprite != null and f.sprite.animation == &"attack" and f.sprite.is_playing())
		if (f.strike_pending or in_pose) and is_instance_valid(f.strike_target):
			target = f.strike_target
		if target == null or u.entering:
			continue
		var reach := u.range_m + 0.35 * (u.size + target.unit.size - 2.0)
		f.contact_blend = 1.0 - smoothstep(reach + 0.32, reach + 2.1, LegionSim.dist(u, target.unit))
		if f.strike_pending or in_pose:
			f.contact_blend = 1.0
		if f.contact_blend > 0.0:
			f.layout_target = target
	# Места меняются с шагом боя, ноги движутся плавно каждый кадр.
	for f in _fighters:
		var target := f.layout_target
		if target == null:
			continue
		if target.layout_target == f:
			target.front = f
			f.slot = 1
			if f.unit.id < target.unit.id:
				var center := (f.goal + target.goal) * 0.5
				center.y = clampf(center.y, -8.0, 8.0)
				var gap := minf(f.strike_distance, target.strike_distance) * 0.36 + f.muzzle + target.muzzle
				f.goal = f.goal.lerp(_fit_foot(f, center + Vector2(f.side_dir * gap * 0.5, 0)), f.contact_blend)
				f.visit = 2
	for priority in 2:
		for f in _fighters:
			var target := f.layout_target
			if target == null or f.slot != 0:
				continue
			var urgent := f.attack_left > 0.0 or f.strike_pending
			if urgent != (priority == 0):
				continue
			if target.front == null:
				target.front = f
				f.slot = 1
			elif target.upper == null and (target.lower != null or f.goal.y <= target.goal.y):
				target.upper = f
				f.slot = 2
			elif target.lower == null:
				target.lower = f
				f.slot = 3
			else:
				f.slot = 4
	for f in _fighters:
		if f.unit.alive:
			_engagement_goal(f)


func _layout(weight: float) -> void:
	for f in _fighters:
		if f.unit.alive:
			if f.spawn_pending:
				f.position = f.goal
				f.spawn_pending = false
			var before := f.position
			f.position = f.position.lerp(f.goal, weight)
			f.travel = f.position - before
	_separate()
	for f in _fighters:
		if not f.unit.alive:
			continue
		var u := f.unit
		var aim := f.aim_target if f.aim_target != null and f.aim_target.alive else u.target
		var target: Fighter = views.get(aim.id) if aim != null and aim.alive else f.layout_target
		if is_instance_valid(f.strike_target) and (f.strike_pending or f.attack_left > 0.0):
			target = f.strike_target
		if target != null and not u.entering:
			f.aim_at(target)
		else:
			f.aim_depth = 0.0
			f.face(u.enter_dir < 0.0 if u.entering else f.side_dir > 0.0)
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
			if not is_instance_valid(f.strike_target):
				f.strike_pending = false
			elif f.slot > 0 and f.slot < 4 and f.can_strike(f.strike_target):
				f.strike_pending = false
				f.attack(f.strike_action)
				melee_pose.emit(f, f.strike_target)


func _engagement_goal(f: Fighter) -> void:
	if f.visit != 0:
		return
	f.visit = 1
	var target := f.layout_target
	if target != null and target.visit != 1 and f.slot > 0:
		_engagement_goal(target)
		var at := target.goal
		# ? ???? ????? ???? ?????????? ??????, ???????? ??? ??? ?????.
		var y := at.y
		var space := f.strike_distance * 0.36
		if f.slot == 2:
			space = f.strike_distance * 0.82
			y = maxf(at.y - f.strike_distance * 0.46, -_trail_depth)
		elif f.slot == 3:
			space = f.strike_distance * 0.07
			y = minf(at.y + f.strike_distance * 0.69, _trail_depth)
		elif f.slot == 4:
			space += maxf(55.0, f.body_width())
			y = f.goal.y
		var dir := f.side_dir
		if f.unit.side == "enemy" and f.unit.enter_dir > 0.0:
			dir = -1.0
		var edge := f.muzzle + target.edge_toward(dir)
		var x := at.x + dir * (edge + space)
		if x * f.side_dir > f.front_limit:
			# Если враг прорвался к стрелкам, догоняем его со стороны своего строя.
			dir = -dir
			x = at.x + dir * (f.muzzle + target.edge_toward(dir) + space)
		f.goal = f.goal.lerp(_fit_foot(f, Vector2(x, y)), f.contact_blend)
	f.visit = 2


func _separate() -> void:
	# Взаимная пара держит центр линии и сохраняет место перед целью.
	for pass_index in 3:
		var moved := false
		var i := 0
		while i < _fighters.size():
			var a := _fighters[i]
			if not a.unit.alive:
				i += 1
				continue
			var j := 0
			while j < i:
				var b := _fighters[j]
				j += 1
				if not b.unit.alive and (b.death < 0.48 or b.modulate.a < 0.25):
					continue
				var both := b.unit.alive
				var space := (a.body_half + b.body_half) * (0.59 if both else 0.40)
				var d := a.position - b.position
				if absf(d.x) >= space or absf(d.y) >= space or d.length_squared() >= space * space:
					continue
				var distance := d.length()
				var direction := d / distance if distance > 0.01 else Vector2(a.side_dir * 0.6, 0.8)
				if not both and pass_index > 0:
					continue
				var push := (space - distance) * (1.0 if both else 0.13)
				if push < 0.75:
					continue
				var share := 1.0 if not both else clampf(b.body_half / (a.body_half + b.body_half), 0.24, 0.76)
				if both and a.wide and b.wide:
					# На узкой тропе длинные корпуса расходятся вдоль поля.
					var dx := sqrt(maxf(0.0, space * space - d.y * d.y)) - absf(d.x)
					var side := 1.0 if d.x >= 0.0 else -1.0
					var x_a := a.position.x
					var x_b := b.position.x
					a.position = _fit_foot(a, a.position + Vector2(side * dx * share, 0))
					b.position = _fit_foot(b, b.position - Vector2(side * dx - (a.position.x - x_a), 0))
					var residual := dx - side * (a.position.x - x_a + x_b - b.position.x)
					if residual > 0.75:
						a.position = _fit_foot(a, a.position + Vector2(side * residual, 0))
					moved = true
					continue
				if both and a.slot != 0 and b.slot == 0:
					share *= 0.45
				elif both and b.slot != 0 and a.slot == 0:
					share = lerpf(share, 1.0, 0.55)
				a.position = _fit_foot(a, a.position + direction * (push * share))
				if both:
					b.position = _fit_foot(b, b.position - direction * (push * (1.0 - share)))
				moved = true
			i += 1
		if not moved:
			break


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
		if _layout_step != sim.steps:
			_plan_layout()
			_layout_step = sim.steps
		_layout(1.0 - exp(-gdt * 14.0))
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


func clear() -> void:
	for root: Node2D in [units, effects]:
		for child in root.get_children():
			root.remove_child(child)
			child.queue_free()
	views.clear()
	_fighters.clear()
	_layout_step = -1
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
	var goal := Vector2.ZERO
	var travel := Vector2.ZERO
	var drawn_foot := Vector2.ZERO
	var spawn_pending := true
	var body_half := 25.0
	var muzzle := 25.0
	var rump := 25.0
	var beam := 50.0
	var front_limit := INF
	var strike_distance := 55.0
	var aim_depth := 0.0
	var front: Fighter
	var upper: Fighter
	var lower: Fighter
	var layout_target: Fighter
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
		var torso := 0.63
		var breadth := torso
		var front_edge := 0.0
		if actor != null and (wide or boss_model != null):
			var bounds := AABB()
			for part: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
				if part.visible and part.mesh != null:
					var hull := actor.global_transform.affine_inverse() * part.global_transform * part.mesh.get_aabb()
					bounds = hull if not bounds.has_volume() else bounds.merge(hull)
			var angle := deg_to_rad(yaw)
			breadth = maxf(breadth, bounds.size.x)
			torso = maxf(torso, bounds.size.x * absf(cos(angle)) + bounds.size.z * absf(sin(angle)))
			if not long_model.is_empty():
				var end: Vector2 = long_model[0]
				front_edge = end.x * cos(angle) + end.y * sin(angle)
				torso = maxf(torso, front_edge * 1.38)
		var units := model_height() / 1.79
		body_half = torso * units * 0.5
		beam = breadth * units
		muzzle = front_edge * units if front_edge > 0.0 else body_half
		rump = maxf(body_half * 0.5, body_width() - muzzle)
		var gear: Array = Enemy.HUMANS.get(unit.key, [])
		var weapon := String(gear[1]) if not gear.is_empty() else ""
		strike_distance = clampf(model_height() * 0.36, 47.0, 72.0)
		if unit.key == "spearman" or weapon in ["spear", "pike", "falx", "axe", "staff"]:
			strike_distance += 18.0

	func body_width() -> float:
		return body_half * 2.0

	func rear_spacing() -> float:
		# Веер вокруг цели: верхнее место дальше, нижнее ближе.
		return maxf(beam * 2.55, 142.0)

	func edge_toward(dir: float) -> float:
		return muzzle if (dir < 0.0) == flip_h else rump

	func can_strike(target: Fighter) -> bool:
		var d := target.body_ground() - body_ground()
		var gap := Vector2(maxf(0.0, absf(d.x) - muzzle - target.edge_toward(-d.x)), d.y)
		return gap.length_squared() <= strike_distance * strike_distance and flip_h == (d.x < 0.0)

	func aim_at(target: Fighter) -> void:
		var d := target.body_ground() - body_ground()
		face(d.x < 0.0)
		aim_depth = clampf(d.y * 0.23, -13.0, 13.0)

	func layout_point(x: float, z: float) -> Vector2:
		if view != null and not view.legacy_layout:
			var depth := clampf(lerpf(lane_z, z, 0.30) * 23.0, -view._trail_depth, view._trail_depth)
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
