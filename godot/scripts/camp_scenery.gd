class_name CampScenery
extends RefCounted
## Городские материалы и детали для отдельного мира лагеря.

const SPAN := 400.0
const ORIGIN := Vector3(SPAN / 2, 2, SPAN / 2)
const MASK_SIZE := 800


static func lighting(world: Node3D, sub: SubViewport, game: Node) -> void:
	var source: Environment = game.get("env")
	var env := source.duplicate(true) as Environment
	# Полдень лагеря не переводит часы и погоду города.
	var sky := source.sky.duplicate(true) as Sky
	var sky_mat := sky.sky_material as ProceduralSkyMaterial
	if sky_mat != null:
		sky_mat.sky_top_color = Color("3d7fd8")
		sky_mat.sky_horizon_color = Color("d9e6ee")
		sky_mat.ground_horizon_color = sky_mat.sky_horizon_color.darkened(0.1)
	env.sky = sky
	env.ambient_light_energy = 0.5
	env.ambient_light_color = Color("c4b8c8")
	env.ambient_light_sky_contribution = 0.3
	env.fog_light_color = Color("e6e4d8")
	if Game.look_fresh:
		env.fog_density = 0.00055
	var we := WorldEnvironment.new()
	we.name = "CityEnvironment"
	we.environment = env
	world.add_child(we)
	var source_sun: DirectionalLight3D = game.get("sun")
	var sun := source_sun.duplicate(0) as DirectionalLight3D
	sun.name = "CampSun11"
	world.add_child(sun)
	# Формула Game._set_hour при h=11, day=1, gold=0.
	var t := (11.0 - 4.6) / 17.6
	var elev := deg_to_rad(4.0 + 44.0 * sin(t * PI))
	var flat := Vector3(1, 0, lerpf(0.9, -0.95, t)).normalized()
	var direction := (flat * cos(elev) + Vector3.UP * sin(elev)).normalized()
	sun.look_at_from_position(world.global_position + direction * 200, world.global_position, Vector3.UP)
	sun.light_color = Color("fff1de")
	sun.light_energy = 2.6
	var source_grade: ShaderMaterial = game.get("grade")
	var grade := source_grade.duplicate() as ShaderMaterial
	grade.set_shader_parameter("gain", Vector3(1.03, 1, 0.94) if Game.look_fresh else Vector3(1.02, 1, 0.97))
	grade.set_shader_parameter("shadow_tint", Vector3(0.9, 0.92, 1) if Game.look_fresh else Vector3(0.93, 0.94, 1))
	grade.set_shader_parameter("green_shift", 0.12 if Game.look_fresh else 0.0)
	grade.set_shader_parameter("sat", 1.1 if Game.look_fresh else 1.08)
	grade.set_shader_parameter("tint", Vector3.ONE)
	grade.set_shader_parameter("warm_keep", 0.0)
	grade.set_shader_parameter("contrast", 1.14)
	grade.set_shader_parameter("rain", 0.0)
	# Внутри SubViewport: цветокоррекция только мира, плашки остаются чистыми.
	var layer := CanvasLayer.new()
	layer.name = "CampGrade"
	layer.layer = 1
	sub.add_child(layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = grade
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func height_at(x: float, z: float) -> float:
	# Внутри ограды ровно, дальше — мягкие невысокие холмы.
	var edge := maxf(absf(x) - 38.0, absf(z) - 29.0)
	var rise := smoothstep(0.0, 34.0, edge)
	return rise * (2.8 + 1.8 * sin(x * 0.045 + 0.5) * cos(z * 0.038) + 0.7 * sin(z * 0.071))


static func _mask_rect(img: Image, rect: Rect2, col: Color) -> void:
	var a := Vector2i((rect.position + Vector2.ONE * SPAN / 2) * MASK_SIZE / SPAN)
	var sz := Vector2i(rect.size * MASK_SIZE / SPAN)
	img.fill_rect(Rect2i(a, sz), col)


static func terrain(world: Node3D, game: Node, plots: Dictionary) -> void:
	var source: ShaderMaterial = game.get("land_mat")
	var mat := source.duplicate() as ShaderMaterial
	var mask := Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 1))
	# Via principalis, боковые дорожки, дворы: та же маска, что у города.
	_mask_rect(mask, Rect2(-2.75, -20, 5.5, 64), Color(1, 0, 0, 1))
	for z: float in [-15, 0, 14]:
		_mask_rect(mask, Rect2(-28, z - 1.5, 56, 3), Color(1, 0, 0, 1))
	for slot: String in plots:
		var p: Vector3 = plots[slot]
		var paved := slot in ["hq", "mars"]
		_mask_rect(mask, Rect2(p.x - 7, p.z - 5.5, 14, 11), Color(0, 1, 0, 1) if paved else Color(0, 0, 1, 0.3))
	_mask_rect(mask, Rect2(-30, -22, 18, 8), Color(0, 0, 1, 0.65))
	# Дорога из ворот уходит через луг, а не обрывается у ограды.
	for i in 52:
		var z := 43.0 + i * 3.0
		var x := sin((z - 43) * 0.025) * 14.0
		_mask_rect(mask, Rect2(x - 2.5, z, 5, 3.5), Color(0, 0, 1, 1))
	mask.generate_mipmaps()
	mat.set_shader_parameter("surf", ImageTexture.create_from_image(mask))
	mat.set_shader_parameter("map_size", SPAN)
	mat.set_shader_parameter("own_on", false)
	mat.set_shader_parameter("deco_on", false)
	mat.set_shader_parameter("prev_mode", 0)
	mat.set_shader_parameter("wet", 0.0)
	# Та же земля Meadow, включая палитру, шум, клевер и текстуру троп.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const STEP := 4.0
	var cells := int(SPAN / STEP)
	for iz in cells + 1:
		for ix in cells + 1:
			var x := ix * STEP - SPAN / 2
			var z := iz * STEP - SPAN / 2
			var y := height_at(x, z)
			var dx := height_at(x + 0.1, z) - height_at(x - 0.1, z)
			var dz := height_at(x, z + 0.1) - height_at(x, z - 0.1)
			st.set_normal(Vector3(-dx / 0.2, 1, -dz / 0.2).normalized())
			st.set_color(Land.C_GRASS[2].srgb_to_linear())
			st.set_uv(Vector2(0, y + ORIGIN.y))
			st.set_uv2(Vector2(0, 1))
			st.add_vertex(Vector3(x, y, z))
	for iz in cells:
		for ix in cells:
			var a := iz * (cells + 1) + ix
			for idx: int in [a, a + 1, a + cells + 1, a + 1, a + cells + 2, a + cells + 1]:
				st.add_index(idx)
	var ground := MeshInstance3D.new()
	ground.name = "CampTerrain"
	ground.mesh = st.commit()
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ground)


static func surroundings(world: Node3D, plots: Dictionary) -> void:
	var pool := Parts.new()
	pool.name = "CampLandscape"
	pool.tint_split = Parts.split_on
	world.add_child(pool)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3011
	var bp := Bp.new(3011)
	# Секции настоящего деревянного ограждения, высота около двух метров.
	for z: float in [-24, 24]:
		for i in 28:
			var x := -35.0 + i * 2.5
			if z > 0 and x >= -5 and x < 5:
				continue
			bp.add_xf("SM_Env_Fence_Wood_03", Transform3D(Basis.from_scale(Vector3(1, 1.65, 1)), Vector3(x, 0, z)))
	for x: float in [-35, 35]:
		for i in 19:
			bp.add_xf("SM_Env_Fence_Wood_03", Transform3D(Basis(Vector3.UP, -PI / 2).scaled_local(Vector3(1.01, 1.65, 1)), Vector3(x, 0, -24 + i * 2.5)))
	# Открытые створки не преграждают путь новобранцам.
	for side: float in [-1, 1]:
		bp.add_xf("SM_Prop_Pole_01", Transform3D(Basis.from_scale(Vector3(1.5, 1.5, 1.5)), Vector3(side * 5, 0, 24)))
		bp.add("SM_Env_Fence_Wood_Gate_01", Vector3(side * 5, 0, 24), side * PI / 2, 1.5)
		bp.add("#mil_standard", Vector3(side * 5, 4.4, 24), 0, 0.85)
	for x: float in [-5, -2.5, 0, 2.5]:
		bp.add_xf("SM_Prop_Beam_01", Transform3D(Basis.from_scale(Vector3(1, 1.5, 1.5)), Vector3(x, 4.3, 24)))
	bp.add("SM_Prop_Banner_03_A", Vector3(0, 4.2, 24.2), 0, 1.15)
	# В Ancient Empire нет палаток: берём общий городской комплект Легиона.
	for z: float in [-21, -16.5]:
		for x: float in [-28, -22, -16]:
			bp.add("#mil_tent", Vector3(x, 0, z), 0, 1.25)
			bp.add("SM_Prop_Sack_01", Vector3(x + 1.7, 0, z + 1), 0.3, 0.8)
	pool.place(bp, Transform3D.IDENTITY)
	# Лёгкие деревья Ancient Empire: всего четыре группы независимо от числа деревьев.
	for i in 130:
		var x := rng.randf_range(-150, 150)
		var z := rng.randf_range(-150, 150)
		if absf(x) < 43 and absf(z) < 34:
			continue
		if z > 20 and absf(x) < 28:
			continue
		var model: String = ["SM_Env_Tree_01", "SM_Env_Tree_03", "SM_Env_Tree_Thin_01", "SM_Env_Bush_Cluster_02"][i % 4]
		var s := rng.randf_range(0.8, 1.5)
		pool.place_one(model, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3.ONE * s), Vector3(x, height_at(x, z), z)), {"tint": Game.NATURE_GREEN})
	for i in 22:
		var x := rng.randf_range(-100, 100)
		var z := rng.randf_range(-100, 100)
		if absf(x) < 41 and absf(z) < 32:
			continue
		pool.place_one("SM_Env_Rock_Cliff_01", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3.ONE * rng.randf_range(0.12, 0.3)), Vector3(x, height_at(x, z) - 0.12, z)))
	for i in (180 if MeadowNature.low else 480):
		var x := rng.randf_range(-65, 65)
		var z := rng.randf_range(-52, 52)
		if absf(x) < 4 or (absf(x) < 30 and (absf(z + 15) < 2.4 or absf(z) < 2.4 or absf(z - 14) < 2.4)):
			continue
		if x > -31 and x < -12 and z > -23 and z < -13:
			continue
		var clear := true
		for p: Vector3 in plots.values():
			if absf(x - p.x) < 7.8 and absf(z - p.z) < 6.3:
				clear = false
		if not clear:
			continue
		var model := "SM_Env_Grass_01" if i % 4 < 2 else ("SM_Env_Flowers_01" if i % 4 == 2 else "SM_Env_Grass_03")
		pool.place_one(model, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3.ONE * rng.randf_range(0.65, 1.25)), Vector3(x, height_at(x, z), z)))


static func pavilion(root: Node3D, slot: String) -> void:
	var b := Bp.new(73)
	b.paint(1, false)
	b.roof_tex = "Roof_Tile_03"
	b.tint = Color("d6ac80") if slot == "barracks" else Color("e6d4b4")
	b.ground_style = "brick"
	b.remap = b.floor_remap(0)
	var shed := slot in ["forge", "store"]
	var width := 12.5 if slot in ["hq", "barracks"] else 10.0
	var h := 4.5 if slot == "hq" else (3.6 if slot == "mars" else 3.0)
	var n := int(width / Bp.M)
	# Задняя стена и короткие торцы; передняя половина открыта сверху и со стороны камеры.
	for i in n:
		var x := -width / 2 + i * Bp.M
		var wall := "SM_Bld_Wall_Window_06" if i % 2 == 0 else "SM_Bld_Wall_01"
		if slot == "hq" and i == n / 2:
			wall = "SM_Bld_Wall_Door_Double_01"
		var skin := b.floor_remap(0)
		if shed:
			skin = CatCivic._skin(b, "Building_Large_Brick_01", Color("cfad87"))
		b.remap = skin
		b.add_xf(wall, Transform3D(Basis.from_scale(Vector3(1, h / 3, 1)), Vector3(x, 0.08, -4.2)), true)
		b.add("SM_Bld_Trim_04", Vector3(x, h - 0.25, -4.2), 0, 1, true)
		b.add("SM_Bld_Trim_05", Vector3(x, 0.08, -4.2), 0, 1, true)
		if wall == "SM_Bld_Wall_Door_Double_01":
			b.add("SM_Bld_Door_05", Vector3(x + 0.25, 0.08, -4.12), 0, h / 3)
	for side: float in [-1, 1]:
		b.add_xf("SM_Bld_Wall_01", Transform3D(Basis(Vector3.UP, side * PI / 2).scaled_local(Vector3(1, h / 3, 1)), Vector3(side * width / 2, 0.08, -1.7 if side > 0 else -4.2)), true)
		b.add("SM_Bld_Wall_End_01", Vector3(side * width / 2, 0.08, -4.2), 0, 1, true)
	# Черепичная крыша над задней частью — настоящие скаты, конёк и карнизы Synty.
	b.remap = b.floor_remap(1)
	if shed:
		CatCivic._shed(b, -width / 2 - 0.2, width / 2 + 0.2, -1.8, -4.5, h, "", 0.8, false)
	else:
		CatCivic._hip(b, -width / 2 - 0.25, width / 2 + 0.25, -4.6, -1.7, h + 0.1, 1.25)
		b.add("SM_Bld_Roof_Topper_01", Vector3(0, h + 1.02, -3.15), 0, 0.9)
	for x: float in [-width / 2, width / 2]:
		if shed:
			b.add_xf("SM_Prop_Pole_01", Transform3D(Basis.from_scale(Vector3(0.75, h / 3, 0.75)), Vector3(x, 0.08, -1.7)))
		else:
			b.add("SM_Bld_Pillar_02", Vector3(x, 0.08, -1.5), 0, h / 3)
	if slot in ["hq", "mars", "barracks"]:
		for x: float in [-width / 2, width / 2]:
			b.add("SM_Bld_Pillar_02", Vector3(x, 0.08, 2.7), 0, h / 3)
			b.add("SM_Prop_Banner_03_A", Vector3(x, h - 0.3, 2.95), 0, 0.65)
			# Узкая боковая галерея связывает передние колонны с задним залом.
			CatCivic._hip(b, x - 0.48, x + 0.48, -1.7, 3.15, h + 0.1, 0.7, false)
		b.add("SM_Env_Ivy_Flowers_02", Vector3(-width / 2 + 0.2, h - 0.5, -3.9), 0, 0.65)
	match slot:
		"barracks":
			for x: float in [-4.3, 0, 4.3]:
				b.add("SM_Wep_Shield_04", Vector3(x, 2.2, -3.9), 0, 0.75)
			CatMilitary._rack(b, Vector3(-5, 0.08, 3.2), 0, 2, 0.85)
		"hq":
			b.add("#mil_eagle", Vector3(0, h + 1, -3.1), 0, 1.1)
			b.add("SM_Prop_Banner_03_A", Vector3(-3.7, h - 0.2, -3.9), 0, 1.1)
			b.add("SM_Prop_Banner_03_A", Vector3(3.7, h - 0.2, -3.9), 0, 1.1)
		"forge":
			# Отдельная труба именно у горна, не возвращает трубы городским домам.
			b.remap = CatCivic._skin(b, "Building_Large_Brick_01", Color("cfad87"))
			b.add_xf("SM_Bld_Wall_End_01", Transform3D(Basis.from_scale(Vector3(1.8, 1.7, 1.8)), Vector3(4, 0.1, -1.5)), true)
			CatMilitary._rack(b, Vector3(-3.4, 0.08, -2.6), 0, 2, 0.75)
			b.add("SM_Prop_Table_04", Vector3(-4, 0.08, 2.8), 0, 1)
			b.add("SM_Prop_Tool_Hammer_01", Vector3(-4, 0.9, 2.8), 0.4)
			b.add("SM_Prop_Tool_Chisel_01", Vector3(-3.5, 0.9, 2.8), 0.7)
		"store":
			b.add("SM_Prop_Sack_Stack_02", Vector3(-4, 0.08, 1), 0, 1.2)
			b.add("SM_Prop_Jar_Pile_01", Vector3(3.8, 0.08, -2), 0, 1.1)
	var pool := Parts.new()
	pool.name = "CityPieces"
	pool.tint_split = Parts.split_on
	root.add_child(pool)
	pool.place(b, Transform3D.IDENTITY)
	root.set_meta("cutaway", true)
	root.set_meta("city_piece_count", b.parts.size())


static func floor_material(slot: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	var tex := "Floor_Tiles_03" if slot in ["hq", "mars"] else "Floor_Tiles_04"
	mat.albedo_texture = Gfx.tex(Synty._tex_path(tex))
	mat.uv1_scale = Vector3(5, 4, 1)
	mat.albedo_color = Color("e5d7bd")
	if slot in ["drill", "forge", "store"] and MeadowNature.on():
		mat.albedo_texture = Gfx.tex(Meadow._tex_path("Dirt_Cracked_Pebbles_Texture_01"))
		mat.albedo_color = Color("d3bb94")
	return mat
