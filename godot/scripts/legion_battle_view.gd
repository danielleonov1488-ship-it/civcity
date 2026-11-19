class_name LegionBattleView
extends Control
## Рисованное поле боя. Читает позы и события LegionSim, не меняет состояние боя.

const FortPerson = preload("res://scripts/fort_person.gd")
const Actor = preload("res://scripts/charpilot_actor.gd")
const Enemy = preload("res://scripts/legion_enemy_actor.gd")
const Boss = preload("res://scripts/legion_boss_model.gd")
const PersonLayer = preload("res://scripts/fort_person_layer.gd")
const ART := "res://assets/legion_b1/"
const DESIGN := Vector2(1600, 900)
const CELL := 256
const BASELINE := 242
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
var _zoom := 1.0


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
	people_layer.setup("BattlePeople3D", 5.0)
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
	_fit()


func set_zoom(value: float) -> void:
	_zoom = value
	_fit()


func _fit() -> void:
	var cover_h := maxf(size.y, size.x * 1080.0 / 2560.0)
	var path_y := size.y * 0.5 + (_trail_y - 0.5) * cover_h
	world.position = Vector2(size.x * 0.5, minf(path_y, size.y * 0.79))
	world.scale = Vector2.ONE * maxf(0.001, minf(size.x / DESIGN.x, size.y / DESIGN.y) / _zoom)
	people_layer.fit(size)
	for f: Fighter in views.values():
		_place_actor(f)


static func point(x: float, z: float) -> Vector2:
	# Поперечные ряды немного сдвинуты вбок, чтобы бойцы одного строя были видны.
	var px := x * 73.0 + z * 126.0
	if absf(px) > 530.0:
		px = signf(px) * (530.0 + (absf(px) - 530.0) * 0.27)
	return Vector2(px, z * 43.0)


func screen(p: Vector2) -> Vector2:
	return world.position + p * world.scale


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
		f.yaw = 48.0 if loadout["outfit"] == "archer" else 56.0
		f.idle_clip = "Spell_Simple_Idle" if loadout["outfit"] == "archer" else ("Sword_Idle" if bool(loadout["sword"]) else "Idle")
		f.attack_clip = "Spell_Simple_Shoot" if loadout["outfit"] == "archer" or u.heal_pow > 0.0 else "Sword_Attack"
		f.clip = f.idle_clip
		if u.side == "enemy":
			f.hit_clip = "Hit_Chest"
			f.death_clip = "Death01"
	else:
		_add_enemy(f)
	if f.actor != null and not f.actor.problem.is_empty():
		f.actor.free()
		f.actor = null
	if f.actor == null:
		f.sprite = AnimatedSprite2D.new()
		f.sprite.name = ("EnemySprite" if u.side == "enemy" else "AllySprite")
		f.sprite.sprite_frames = _unit_frames(f.sheet)
		f.add_child(f.sprite)
		f.sprite.play(&"idle")
	f.position = f.layout_point(u.x, u.z)
	f.face(u.side == "enemy" and (not u.entering or u.enter_dir < 0.0))
	_place_actor(f)
	views[u.id] = f
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


func _place_actor(f: Fighter) -> void:
	if not is_instance_valid(f.actor):
		return
	var feet := screen(f.position)
	var height := f.model_height() * world.scale.y
	f.actor.visible = f.modulate.a > 0.0 and Rect2(Vector2.ZERO, size).grow(height).has_point(feet)
	if f.actor.visible:
		var angle := -f.yaw if f.flip_h else f.yaw
		if f.backward_shot():
			angle -= 180.0 if angle > 0.0 else -180.0
		people_layer.place(f.actor, feet, height, angle, false, -4.6 if f.wide else 0.0)
		f.actor.set_opacity(f.modulate.a)
		f.actor.animate(f.clip, f.sample)


func burst(kind: String, where: Vector2, radius := 1.0, tint := Color.WHITE) -> void:
	if _bursts.size() >= 48:
		_bursts.pop_front().queue_free()
	var f := Burst.new()
	f.sprite_frames = _effect_frames(kind)
	f.animation = &"effect"
	f.position = where
	f.scale = Vector2.ONE * radius
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
	effects.add_child(sprite)
	shots[s] = sprite
	var source: Fighter = views.get(s.from.id) if s.from != null else null
	if source != null and source.boss_model != null and source.unit.key in ["cyclops", "horseArcher"]:
		source.actor.pose_at(source.attack_clip, 0.0)
		_place_actor(source)
		var launch := people_layer.camera.unproject_position(source.boss_model.launch_point())
		sprite.set_meta("boss_launch", (launch - world.position) / world.scale)
	_place_shot(s, sprite, 0.0)


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
	if sprite.has_meta("boss_launch"):
		a = sprite.get_meta("boss_launch")
	var b := (target.layout_point(s.x1, s.z1) if target != null else point(s.x1, s.z1)) - Vector2(0, 100.0)
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
	for id in views.keys():
		var f: Fighter = views[id]
		f.tick(gdt, gdt / dt if dt > 0.0 else 0.0, weight, fighting, sim.t)
		_place_actor(f)
		if f.unit.alive:
			f.status(sim.t, fighting)
		elif f.modulate.a <= 0.0:
			f.queue_free()
			views.erase(id)
	for s: LegionSim.Shot in shots.keys():
		var sprite: Node2D = shots[s]
		if s.done or not sim.result.is_empty():
			sprite.queue_free()
			shots.erase(s)
		else:
			_place_shot(s, sprite, clampf((s.t + acc) / s.dur, 0.0, 1.0))
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
	var boss_model: Boss
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

	func layout_point(x: float, z: float) -> Vector2:
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
			p.y -= 31.0
		return p

	func body_height() -> float:
		if actor_height > 0.0:
			return model_height() * actor_height / 1.79
		var y := 26.0 if sheet == "bear" and sprite != null and sprite.animation == &"attack" else silhouette.y
		return (LegionBattleView.BASELINE - y) * scale.y

	func model_height() -> float:
		return 234.0 * scale.y if actor_height > 0.0 else body_height()

	func head() -> Vector2:
		return position - Vector2(0, body_height() + 10.0)

	func chest() -> Vector2:
		return position.lerp(head(), 0.55)

	func backward_shot() -> bool:
		return boss_model != null and unit.key == "horseArcher" and clip in ["Windup", attack_clip]

	func attack(action := "") -> void:
		if sprite != null:
			sprite.stop()
			sprite.play(&"attack")
		else:
			clip = attack_clip if action.is_empty() else action
			sample = 0.0
			attack_left = actor.clip_length(clip)
			hit_left = 0.0

	func hurt() -> void:
		flash = 0.14
		modulate = Color(1.8, 1.24, 1.12)
		if actor != null and not hit_clip.is_empty() and unit.alive and (boss_model == null or attack_left <= 0.0):
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
		if sprite != null:
			sprite.play(&"idle")

	func tick(gdt: float, rate: float, weight: float, fighting: bool, now: float) -> void:
		if not unit.alive:
			if sprite != null:
				sprite.speed_scale = 0.0
			if actor != null and not death_clip.is_empty():
				var duration := 0.91 if boss_model == null else (1.42 if unit.key == "elephant" else 1.17)
				death = minf(1.0, death + gdt / duration)
				clip = death_clip
				sample = minf(0.999, death / (0.94 if boss_model != null else 0.73)) * actor.clip_length(death_clip)
				modulate.a = 1.0 - smoothstep(0.39, 1.0, death)
			else:
				death = minf(1.0, death + gdt / 0.63)
				modulate.a = 1.0 - death
			return
		flash = maxf(0.0, flash - gdt)
		modulate = Color.WHITE.lerp(Color(1.8, 1.24, 1.12), flash / 0.14)
		health = lerpf(health, unit.hp_frac(), weight)
		var p := layout_point(unit.x, unit.z)
		var direction_x := p.x - position.x
		var last_x := position.x
		position = position.lerp(p, weight)
		if unit.side == "enemy":
			if unit.entering:
				face(unit.enter_dir < 0.0)
			elif unit.target != null and unit.target.alive and absf(unit.target.x - unit.x) > 0.16:
				face(unit.target.x < unit.x)
			elif unit.moving and absf(direction_x) > 3.0:
				face(direction_x < 0.0)
		var walking := (unit.moving or unit.entering) and fighting
		var walk_rate := clampf(unit.speed / 1.5, 0.7, 1.65)
		if boss_model != null:
			boss_model.moving = walking
			var direction := -1.0 if flip_h else 1.0
			boss_model.roll((position.x - last_x) * direction * 1.79 / (model_height() * sin(deg_to_rad(yaw))))
		if sprite != null:
			if sprite.animation != &"attack" or not sprite.is_playing():
				sprite.play(&"walk" if walking else &"idle")
			sprite.speed_scale = rate * (walk_rate if sprite.animation == &"walk" else 1.0)
		elif hit_left > 0.0:
			sample += minf(gdt, maxf(0.0, hit_left - 0.001))
			hit_left = maxf(0.0, hit_left - gdt)
		elif attack_left > 0.0:
			sample += minf(gdt, maxf(0.0, attack_left - 0.001))
			attack_left = maxf(0.0, attack_left - gdt)
		elif boss_model != null and fighting and _windup(now):
			clip = "Windup"
			var length := actor.clip_length(clip)
			sample = clampf(length - unit.timer, 0.0, length)
		else:
			var next := walk_clip if walking else idle_clip
			sample = sample + gdt * (walk_rate if walking else 1.0) if clip == next else 0.0
			clip = next

	func _windup(now: float) -> bool:
		if unit.key not in ["cyclops", "horseArcher"] or unit.entering or unit.target == null or not unit.target.alive:
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

	func tick(dt: float) -> void:
		time += dt
		for list: Array in [marks, lanes]:
			for i in range(list.size() - 1, -1, -1):
				list[i]["t"] = float(list[i]["t"]) - dt
				if float(list[i]["t"]) <= 0.0:
					list.remove_at(i)
		queue_redraw()

	func _draw() -> void:
		for lane_mark in lanes:
			var z := float(lane_mark["z"])
			var tint: Color = lane_mark["color"]
			tint.a *= sin(float(lane_mark["t"]) / float(lane_mark["lifetime"]) * PI) * 0.7
			draw_line(LegionBattleView.point(-15.0, z), LegionBattleView.point(15.0, z), tint, float(lane_mark["width"]), true)
		for f: Fighter in views.values():
			var foot := f.position + Vector2(0, 2)
			draw_set_transform(foot, 0.0, Vector2(1.0, 0.22 if not f.wide else 0.18))
			var r := (65.0 if f.wide else 39.0) * f.scale.x
			draw_circle(Vector2.ZERO, r * 1.15, Color(0.24, 0.11, 0.04, 0.19 * f.modulate.a), true, -1.0, true)
			draw_circle(Vector2.ZERO, r, Color(0.24, 0.11, 0.04, 0.27 * f.modulate.a), true, -1.0, true)
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
