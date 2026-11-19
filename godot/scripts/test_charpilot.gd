extends Node3D
## Сравнение персонажей в одной комнате B1.

const Actor := preload("res://scripts/charpilot_actor.gd")
const OUT := "D:/CivCity/.work/stage7/charkit/shots/godot/"
const ROOM := "res://assets/legion_b1/rooms/barracks_2.jpg"
const SIZE := Vector2i(1200, 800)
const SHOTS := ["A_outfits", "A_in_room", "B_outfits", "B_in_room", "C_current"]
const TITLES := ["A · Quaternius", "B · Synty", "C · Текущие спрайты"]
const CAPTIONS := ["Крестьянин", "Мастер", "Легионер"]
const KIT_CAPTIONS := {
	"peasant": "Крестьянин", "worker": "Мастер", "legionary": "Легионер",
	"centurion": "Центурион", "patrician": "Патриций", "toga": "Тога",
	"cook": "Повар", "smith": "Кузнец", "archer": "Лучник", "priest": "Жрец",
}
const OUTFIT_FEET := [Vector2(295, 695), Vector2(600, 695), Vector2(905, 695)]
const PAIR_FEET := [Vector2(415, 695), Vector2(785, 695)]
const ROOM_FEET := [Vector2(232, 714), Vector2(463, 641), Vector2(719, 718), Vector2(942, 667)]
const JOBS := ["Interact", "Fixing_Kneeling", "Walk", "Sword_Attack"]
const KIT_ROOM := ["smith", "cook", "archer", "legionary"]
const SAMPLE_TIMES := [0.80, 2.10, 0.36, 0.67]
const ROOM_GENDER := [true, false, false, true]
const FACINGS := [18.0, -24.0, 28.0, -20.0]

const EDGE := """
shader_type canvas_item;
render_mode blend_premul_alpha;

void fragment() {
	vec4 picture = texture(TEXTURE, UV);
	float mask = picture.a;
	vec2 step_px = TEXTURE_PIXEL_SIZE * 1.65;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		mask = max(mask, texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * step_px).a);
	}
	float edge = max(0.0, mask - picture.a) * 0.88;
	COLOR = vec4(picture.rgb + vec3(0.086, 0.056, 0.047) * edge, picture.a + edge);
}
"""

var game: Game
var out := OUT
var preview := ""
var _screen: SubViewport
var _view: Node2D
var _world: SubViewport
var _camera: Camera3D
var _actors: Array[Actor] = []
var _shadows: Array[TextureRect] = []
var _sprites: Array[Sprite2D] = []
var _feet: Array[Vector2] = []
var _clips: Array[String] = []
var _samples: Array[float] = []
var _motion := ""
var _time := 0.0
var _shadow_texture: GradientTexture2D


func _ready() -> void:
	if not check(DisplayServer.get_name() != "headless", "a graphics renderer is required"):
		return
	for arg in OS.get_cmdline_user_args():
		var pair := arg.split("=", true, 1)
		if pair.size() != 2:
			continue
		if pair[0] == "out":
			out = pair[1].replace("\\", "/").trim_suffix("/") + "/"
		elif pair[0] == "preview":
			preview = pair[1]
	Game.boot = {"new": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate() as Game
	add_child(game)
	game.can_save = false
	_run()


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func check(ok: bool, reason: String) -> bool:
	if not ok:
		print("CHARPILOT FAIL ", reason)
		get_tree().quit(1)
	return ok


func _run() -> void:
	var waited := 0
	while not game.ready_done:
		await frames(5)
		waited += 5
		if not check(waited < 18000, "ready_done timeout"):
			return
	game.settings["autosave"] = false
	game.hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_make_display()
	var files: Array[String] = []
	files.assign(SHOTS)
	for role: String in Actor.STYLES:
		files.append("B_" + role)
	if preview != "":
		if not check(preview in files, "unknown preview " + preview) or not _build_shot(preview):
			return
		_motion = preview
		return
	if not check(DirAccess.make_dir_recursive_absolute(out) == OK, "shot directory " + out):
		return
	var shots := {}
	for file in files:
		if not _build_shot(file):
			return
		var image := await shot(file)
		if image == null:
			return
		if file in SHOTS:
			shots[file] = image
	if not _compare(shots):
		return
	print("CHARPILOT DONE")
	get_tree().quit()


func _make_display() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_screen = SubViewport.new()
	_screen.size = SIZE
	_screen.disable_3d = true
	_screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_screen)
	var matte := ColorRect.new()
	matte.color = Color("201513")
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(matte)
	var display := TextureRect.new()
	display.texture = _screen.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(display)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.36, 1.0])
	ramp.colors = PackedColorArray([Color(0.16, 0.08, 0.04, 0.57),
		Color(0.16, 0.08, 0.04, 0.33), Color(0.16, 0.08, 0.04, 0.0)])
	_shadow_texture = GradientTexture2D.new()
	_shadow_texture.gradient = ramp
	_shadow_texture.fill = GradientTexture2D.FILL_RADIAL
	_shadow_texture.fill_from = Vector2(0.5, 0.5)
	_shadow_texture.fill_to = Vector2(1.0, 0.5)


func _build_shot(file: String) -> bool:
	if is_instance_valid(_view):
		_screen.remove_child(_view)
		_view.queue_free()
	_world = null
	_actors.clear()
	_shadows.clear()
	_sprites.clear()
	_feet.clear()
	_clips.clear()
	_samples.clear()
	_view = Node2D.new()
	_screen.add_child(_view)
	var room := load(ROOM) as Texture2D
	if not check(room != null, "B1 barracks art missing"):
		return false
	_rect(room, Vector2.ZERO, Vector2(SIZE))
	var family := 0 if file.begins_with("A") else (1 if file.begins_with("B") else 2)
	var outfits := file.ends_with("outfits")
	var kit_role := file.trim_prefix("B_")
	var pair: bool = family == 1 and KIT_CAPTIONS.has(kit_role)
	_feet.assign(PAIR_FEET if pair else (OUTFIT_FEET if outfits else ROOM_FEET))
	if family == 2:
		if not _reference():
			return false
	else:
		_make_world()
		for i in _feet.size():
			var female: bool = i == 0 if pair else (true if outfits else ROOM_GENDER[i])
			var variant := "A" if pair or outfits or i % 2 == 0 else "C"
			var role: String = KIT_ROOM[i] if family == 1 else ("legionary" if i == 3 else "worker")
			if pair:
				role = kit_role
			elif outfits:
				role = Actor.A_STYLES[i]
			var actor := Actor.new()
			_world.add_child(actor)
			if not check(actor.build(family, female, variant), "%s %d %s" % [file, i, actor.problem]):
				return false
			var head: Array[MeshInstance3D] = actor.identity.duplicate()
			for next: String in (Actor.A_STYLES if family == 0 else Actor.STYLES):
				if not check(actor.set_outfit(next) and actor.has_outfit(next) and actor.identity == head,
						"%s %d outfit/identity %s" % [file, i, next]):
					return false
				for part in head:
					if not check(part.is_visible_in_tree(), "%s identity hidden" % file):
						return false
			actor.set_outfit(role)
			var clip: String = JOBS[i]
			var at: float = SAMPLE_TIMES[i]
			if pair or outfits:
				clip = "Sword_Idle" if role in ["legionary", "centurion"] else "Idle"
				at = 0.24
			if not check(actor.pose_at(clip, at), "%s %s %s" % [file, clip, actor.problem]):
				return false
			_actors.append(actor)
			_clips.append(clip)
			_samples.append(at)
			var factor := 1.0 if pair or outfits else (0.90 if i == 1 or i == 3 else 1.0)
			var size_px := Vector2(138.0, 39.0) * factor
			_shadows.append(_rect(_shadow_texture, _feet[i] - size_px * 0.5 + Vector2(8, 3), size_px))
			_place(i, _feet[i], factor, 14.0 if outfits or pair else FACINGS[i])
			if pair:
				_label(I18n.t("Женщина" if female else "Мужчина"),
					Vector2(_feet[i].x - 100, 730), Vector2(200, 44), 25)
			elif outfits:
				_label(("%s · " % ["A" if family == 0 else "B"]) + I18n.t(CAPTIONS[i]),
					Vector2(_feet[i].x - 135, 730), Vector2(270, 44), 25)
		_overlay()
	var title := I18n.t(TITLES[family])
	if pair:
		title += " · " + I18n.t(KIT_CAPTIONS[kit_role])
	_label(title, Vector2(28, 24), Vector2(435 if pair else 315, 55), 31)
	return true


func _make_world() -> void:
	_world = SubViewport.new()
	_world.size = SIZE
	_world.own_world_3d = true
	_world.transparent_bg = true
	_world.msaa_3d = Viewport.MSAA_4X
	_world.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_view.add_child(_world)
	var sky := WorldEnvironment.new()
	sky.environment = Environment.new()
	sky.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.environment.ambient_light_color = Color("eadfcd")
	sky.environment.ambient_light_energy = 0.55
	_world.add_child(sky)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 4.4
	_camera.position = Vector3(0.0, 2.55, 6.0)
	_world.add_child(_camera)
	_camera.look_at(Vector3(0.0, 1.12, 0.0))
	_camera.make_current()
	_light(Color("ffe0ad"), 1.35, Vector3(-36, -27, 0))
	_light(Color("fff1cf"), 0.75, Vector3(-34, 151, 0))


func _light(color: Color, energy: float, angles: Vector3) -> void:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.rotation_degrees = angles
	_world.add_child(light)


func _place(i: int, feet: Vector2, factor: float, yaw: float) -> void:
	var actor := _actors[i]
	var origin := _camera.project_ray_origin(feet)
	var ray := _camera.project_ray_normal(feet)
	actor.position = origin - ray * (origin.y / ray.y)
	var pixels := feet.distance_to(_camera.unproject_position(actor.position + Vector3.UP))
	actor.scale = Vector3.ONE * (float(SIZE.y) * 0.40 * factor / (1.79 * pixels))
	actor.rotation.y = deg_to_rad(yaw)
	_shadows[i].position = feet - _shadows[i].size * 0.5 + Vector2(8, 3)


func _overlay() -> void:
	var overlay := _rect(_world.get_texture(), Vector2.ZERO, Vector2(SIZE))
	var edge := Shader.new()
	edge.code = EDGE
	var outline := ShaderMaterial.new()
	outline.shader = edge
	overlay.material = outline


func _reference() -> bool:
	var roles := ["forge", "kitchen", "", "barracks"]
	for i in _feet.size():
		var person := {"female": ROOM_GENDER[i], "cls": "legionary"}
		var art := FortCutaway.person_art(person, roles[i])
		var sprite := Sprite2D.new()
		sprite.texture = load(FortCutaway.ART + "chars/" + art + ".png") as Texture2D
		if not check(sprite.texture != null, "B1 sprite missing " + art):
			sprite.free()
			return false
		sprite.hframes = 8
		sprite.offset.y = 128.0 - 242.0
		sprite.position = _feet[i]
		var factor := 0.90 if i == 1 or i == 3 else 1.0
		sprite.scale = Vector2.ONE * (float(SIZE.y) * 0.40 * factor / 242.0)
		sprite.frame = 6 if i == 0 or i == 1 else (3 if i == 2 else 0)
		sprite.flip_h = FACINGS[i] < 0.0
		_view.add_child(sprite)
		_sprites.append(sprite)
	return true


func _rect(texture: Texture2D, at: Vector2, extent: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = at
	rect.size = extent
	_view.add_child(rect)
	return rect


func _label(value: String, at: Vector2, extent: Vector2, font_size: int) -> void:
	var box := Panel.new()
	var dark := StyleBoxFlat.new()
	dark.bg_color = Color(0.15, 0.087, 0.048, 0.89)
	dark.set_corner_radius_all(7)
	box.add_theme_stylebox_override("panel", dark)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = at
	box.size = extent
	_view.add_child(box)
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("fff0d6"))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_child(label)


func shot(file: String) -> Image:
	await frames(8)
	await RenderingServer.frame_post_draw
	if _world != null:
		var people := _world.get_texture().get_image()
		if not check(people != null and not people.is_empty() and people.get_pixel(2, 2).a < 0.1,
				"3D layer is missing or opaque in " + file):
			return null
		for feet in _feet:
			var count := 0
			for x in range(int(feet.x) - 45, int(feet.x) + 46, 5):
				for y in range(int(feet.y) - 285, int(feet.y) - 20, 5):
					if people.get_pixel(x, y).a > 0.5:
						count += 1
			if not check(count >= 35, "no visible figure in %s at %s" % [file, feet]):
				return null
	var image := _screen.get_texture().get_image()
	return image if _save(image, file) else null


func _save(image: Image, file: String) -> bool:
	var path := out + file + ".png"
	if not check(image != null and not image.is_empty() and image.save_png(path) == OK, "save " + path):
		return false
	print("CHARPILOT SHOT ", path)
	return true


func _compare(shots: Dictionary) -> bool:
	var sheet := Image.create_empty(2 * SIZE.x, 2 * SIZE.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("201513"))
	var positions := [Vector2i.ZERO, Vector2i(SIZE.x, 0), Vector2i(0, SIZE.y)]
	var room_shots := ["A_in_room", "B_in_room", "C_current"]
	for i in room_shots.size():
		var image: Image = shots[room_shots[i]]
		image.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), positions[i])
	for i in 2:
		var image: Image = shots["A_outfits" if i == 0 else "B_outfits"]
		var row := image.get_region(Rect2i(0, 300, SIZE.x, 500))
		row.resize(960, 400, Image.INTERPOLATE_LANCZOS)
		row.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(row, Rect2i(Vector2i.ZERO, row.get_size()), Vector2i(SIZE.x + 120, SIZE.y + 400 * i))
	return _save(sheet, "compare")


func _process(delta: float) -> void:
	if _motion == "":
		return
	_time += delta
	var t := _time
	if _motion == "C_current":
		_sprites[0].frame = 6 + int(t * 4.0) % 2
		_sprites[1].frame = 6 + int(t * 4.0 + 1.0) % 2
		_sprites[2].frame = 2 + int(t * 6.0) % 4
		_sprites[3].frame = int(t * 2.0) % 2
		return
	for i in _actors.size():
		_actors[i].pose_at(_clips[i], t + _samples[i])
	if _motion.ends_with("in_room"):
		var walk := sin(t * 1.1)
		_place(2, _feet[2] + Vector2(51.0 * walk, 0.0), 1.0, 35.0 if cos(t * 1.1) > 0.0 else -35.0)
