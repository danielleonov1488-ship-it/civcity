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


static func height_at(x: float, z: float, bounds := Rect2(-16, -20, 32, 52)) -> float:
	var d := maxf(maxf(bounds.position.x - x, x - bounds.end.x), maxf(bounds.position.y - z, z - bounds.end.y))
	var gap := absf(x) < 2.3 and z > bounds.end.y - 2
	if d < -1.5:
		return 0.0
	if d <= 1.5:
		return 0.0 if gap else 1.2 * clampf(minf(d + 1.5, 1.5 - d), 0, 1)
	if d < 4.0:
		return -1.2 * clampf(minf((d - 1.5) / 0.75, (4.0 - d) / 0.75), 0, 1)
	# За частоколом река с пологими берегами, дальше холмы.
	var river_distance := absf(z - (bounds.position.y - 24))
	if river_distance < 8:
		return lerpf(-0.8, 0.0, smoothstep(5.5, 8.0, river_distance))
	var rise := smoothstep(8.0, 42.0, d)
	return rise * (2.8 + 1.8 * sin(x * 0.045 + 0.5) * cos(z * 0.038) + 0.7 * sin(z * 0.071))


static func _mask_rect(img: Image, rect: Rect2, col: Color) -> void:
	var a := Vector2i((rect.position + Vector2.ONE * SPAN / 2) * MASK_SIZE / SPAN)
	var sz := Vector2i(rect.size * MASK_SIZE / SPAN)
	var clipped := Rect2i(a, sz).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if clipped.has_area():
		img.fill_rect(clipped, col)


static func terrain(world: Node3D, game: Node, plots: Dictionary, bounds: Rect2) -> void:
	var source: ShaderMaterial = game.get("land_mat")
	var mat := source.duplicate() as ShaderMaterial
	var mask := Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 1))
	_mask_rect(mask, Rect2(-2.75, bounds.position.y + 8, 5.5, bounds.size.y + 32), Color(1, 0, 0, 1))
	for point: Vector3 in plots.values():
		_mask_rect(mask, Rect2(minf(0, point.x) - 1.5, point.z + 4.5, absf(point.x) + 3, 3), Color(1, 0, 0, 1))
		_mask_rect(mask, Rect2(point.x - 4.5, point.z - 4.5, 9, 9), Color(0, 0, 1, 0.6))
	# Земля по внешнему откосу и дну рва; травяной гребень остаётся зелёным.
	var outer := bounds.grow(4)
	_mask_rect(mask, Rect2(outer.position, Vector2(outer.size.x, 2.5)), Color(0, 0, 1, 1))
	_mask_rect(mask, Rect2(outer.position.x, bounds.end.y + 1.5, outer.size.x, 2.5), Color(0, 0, 1, 1))
	_mask_rect(mask, Rect2(outer.position.x, bounds.position.y, 2.5, bounds.size.y), Color(0, 0, 1, 1))
	_mask_rect(mask, Rect2(bounds.end.x + 1.5, bounds.position.y, 2.5, bounds.size.y), Color(0, 0, 1, 1))
	for i in 52:
		var z := bounds.end.y + 6 + i * 3
		var x := sin(i * 0.075) * 14.0
		_mask_rect(mask, Rect2(x - 2.5, z, 5, 3.5), Color(0, 0, 1, 1))
	mask.generate_mipmaps()
	mat.set_shader_parameter("surf", ImageTexture.create_from_image(mask))
	mat.set_shader_parameter("map_size", SPAN)
	mat.set_shader_parameter("own_on", false)
	mat.set_shader_parameter("deco_on", false)
	mat.set_shader_parameter("prev_mode", 0)
	mat.set_shader_parameter("wet", 0.0)
	# В сетку явно входят все переломы профиля: под рвом нет плоской земли.
	var xs: Array[float] = []
	var zs: Array[float] = []
	var span := maxf(SPAN, maxf(bounds.size.x, bounds.size.y) * 4.0)
	for i in range(-int(span / 8), int(span / 8) + 1):
		xs.append(i * 4.0)
		zs.append(i * 4.0)
	for offset: float in [-4, -3.25, -2.25, -1.5, -0.5, 0, 0.5, 1.5, 2.25, 3.25, 4]:
		xs.append(bounds.position.x + offset)
		xs.append(bounds.end.x + offset)
		zs.append(bounds.position.y + offset)
		zs.append(bounds.end.y + offset)
	xs.append_array([-2.3, -2.2, 2.2, 2.3])
	for offset: float in [-8, -5.5, 0, 5.5, 8]:
		zs.append(bounds.position.y - 24 + offset)
	xs.sort()
	zs.sort()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: float in zs:
		for x: float in xs:
			var y := height_at(x, z, bounds)
			var dx := height_at(x + 0.05, z, bounds) - height_at(x - 0.05, z, bounds)
			var dz := height_at(x, z + 0.05, bounds) - height_at(x, z - 0.05, bounds)
			st.set_normal(Vector3(-dx / 0.1, 1, -dz / 0.1).normalized())
			st.set_color(Land.C_GRASS[2].srgb_to_linear())
			st.set_uv(Vector2(0, y + ORIGIN.y))
			st.set_uv2(Vector2(0, 1))
			st.add_vertex(Vector3(x, y, z))
	for iz in zs.size() - 1:
		for ix in xs.size() - 1:
			var a := iz * xs.size() + ix
			for idx: int in [a, a + 1, a + xs.size(), a + 1, a + xs.size() + 1, a + xs.size()]:
				st.add_index(idx)
	var ground := MeshInstance3D.new()
	ground.name = "CampTerrain"
	ground.mesh = st.commit()
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ground)


static func surroundings(world: Node3D, plots: Dictionary, bounds: Rect2) -> void:
	var pool := Parts.new()
	pool.name = "CampLandscape"
	pool.tint_split = Parts.split_on
	world.add_child(pool)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3011
	# Лёгкие деревья Ancient Empire: всего четыре группы независимо от числа деревьев.
	for i in 130:
		var x := rng.randf_range(-150, 150)
		var z := rng.randf_range(-150, 150)
		if bounds.grow(10).has_point(Vector2(x, z)) or absf(z - (bounds.position.y - 24)) < 9:
			continue
		if z > 20 and absf(x) < 28:
			continue
		var model: String = ["SM_Env_Tree_01", "SM_Env_Tree_03", "SM_Env_Tree_Thin_01", "SM_Env_Bush_Cluster_02"][i % 4]
		var s := rng.randf_range(0.8, 1.5)
		pool.place_one(model, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3.ONE * s), Vector3(x, height_at(x, z, bounds), z)), {"tint": Game.NATURE_GREEN})
	for i in 22:
		var x := rng.randf_range(-100, 100)
		var z := rng.randf_range(-100, 100)
		if bounds.grow(8).has_point(Vector2(x, z)) or absf(z - (bounds.position.y - 24)) < 9:
			continue
		pool.place_one("SM_Env_Rock_Cliff_01", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3.ONE * rng.randf_range(0.12, 0.3)), Vector3(x, height_at(x, z, bounds) - 0.12, z)))
	for i in (180 if MeadowNature.low else 480):
		var x := rng.randf_range(-65, 65)
		var z := rng.randf_range(-52, 52)
		if absf(x) < 4 or bounds.grow(5).has_point(Vector2(x, z)) or absf(z - (bounds.position.y - 24)) < 9:
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
		pool.place_one(model, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3.ONE * rng.randf_range(0.65, 1.25)), Vector3(x, height_at(x, z, bounds), z)))


static func pavilion(root: Node3D, slot: String, timber := false, shared: Parts = null) -> void:
	var b := Bp.new(73)
	b.paint(1, false)
	b.roof_tex = "Roof_Tile_03"
	b.tint = Color("d6ac80") if slot == "barracks" else Color("e6d4b4")
	b.ground_style = "brick"
	b.remap = b.floor_remap(0)
	var shed := timber or slot in ["forge", "store", "kitchen", "sawmill", "stable", "arsenal", "tannery", "smelter"]
	var width := 12.5 if slot in ["hq", "barracks"] else 10.0
	var h := 4.5 if slot == "hq" else (3.6 if slot == "mars" else 3.0)
	var n := int(width / Bp.M)
	# Задняя стена и короткие торцы; передняя половина открыта сверху и со стороны камеры.
	for i in n:
		var x := -width / 2 + i * Bp.M
		var wall := "SM_Bld_Wall_Window_06" if i % 2 == 0 and not timber else "SM_Bld_Wall_01"
		if slot == "hq" and i == n / 2 and not timber:
			wall = "SM_Bld_Wall_Door_Double_01"
		var skin := b.floor_remap(0)
		if shed:
			skin = CatCivic._skin(b, "Building_Large_Brick_01", Color("cfad87"))
		if timber:
			skin = CatCivic._skin(b, "Wood_02", Color("c4a477"))
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
	if slot in ["hq", "mars", "barracks"] and not timber:
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
	var pool := shared
	if pool == null:
		pool = Parts.new()
		pool.name = "CityPieces"
		pool.tint_split = Parts.split_on
		root.add_child(pool)
	pool.place(b, pool.global_transform.affine_inverse() * root.global_transform)
	root.set_meta("cutaway", true)
	root.set_meta("city_piece_count", b.parts.size())


static func floor_material(slot: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	var tex := "Floor_Tiles_03" if slot in ["hq", "mars"] else "Floor_Tiles_04"
	mat.albedo_texture = Gfx.tex(Synty._tex_path(tex))
	mat.uv1_scale = Vector3(5, 4, 1)
	mat.albedo_color = Color("e5d7bd")
	if slot in ["", "drill", "forge", "store", "kitchen", "stable", "sawmill", "tannery"] and MeadowNature.on():
		mat.albedo_texture = Gfx.tex(Meadow._tex_path("Dirt_Cracked_Pebbles_Texture_01"))
		mat.albedo_color = Color("d3bb94")
	return mat


static var _wood: Dictionary = {}
static var _kit: Dictionary = {}
static var _curb: BoxMesh


static func wood_material(plank := false) -> StandardMaterial3D:
	var key := "Wood_02" if plank else "Wood_01"
	if not _wood.has(key):
		var mat := StandardMaterial3D.new()
		mat.resource_name = "fort_wood_plank" if plank else "fort_wood_log"
		mat.roughness = 0.85
		Synty.has("SM_Prop_Pole_01")
		var path := Synty._tex_path(key)
		if path == "":
			path = "res://assets/synty/Textures/Base/" + key + ".png"
		mat.albedo_texture = Gfx.tex(path)
		_wood[key] = mat
	return _wood[key]


static func kit_meshes(piece: String) -> Array:
	if _kit.has(piece):
		return _kit[piece]
	if piece == "crate":
		var box := Kit.new()
		for i in 6:
			box.boxc(Vector3(-0.55 + i * 0.22, 0, 0), Vector3(0.21, 1.2, 1.1), Color("9b7047").lightened(0.035 * (i % 3)))
		for x: float in [-0.45, 0.45]:
			for z: float in [-0.57, 0.57]:
				box.boxc(Vector3(x, 0, z), Vector3(0.11, 1.25, 0.08), Color("634a35"))
		var mesh := box.mesh()
		mesh.surface_set_material(0, Kit.material(0.9))
		_kit[piece] = [{"mesh": mesh, "transform": Transform3D.IDENTITY}]
		return _kit[piece]
	var scene := load("res://assets/fort/v2/" + piece + ".glb") as PackedScene
	var root := scene.instantiate() as Node3D
	var result: Array = []
	var nodes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		nodes.push_front(root)
	for node: MeshInstance3D in nodes:
		var mesh := node.mesh.duplicate() as Mesh
		for surface in mesh.get_surface_count():
			var mat := node.get_active_material(surface)
			if mat != null:
				var nm := mat.resource_name.to_lower()
				if nm.contains("wood_log"):
					mat = wood_material()
				elif nm.contains("wood_plank"):
					mat = wood_material(true)
				mesh.surface_set_material(surface, mat)
		result.append({"mesh": mesh, "transform": Citizen._rel(node, root) * Transform3D.IDENTITY})
	root.free()
	_kit[piece] = result
	return result


static func flush_kit(parent: Node3D, batches: Dictionary) -> void:
	for piece: String in batches:
		var transforms: Array = batches[piece]
		for entry: Dictionary in kit_meshes(piece):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = entry["mesh"]
			mm.instance_count = transforms.size()
			for i in transforms.size():
				mm.set_instance_transform(i, transforms[i] * entry["transform"])
			var node := MultiMeshInstance3D.new()
			node.name = "FortKit_" + piece
			node.multimesh = mm
			parent.add_child(node)


static func foundation(root: Node3D, empty: bool, pool: Parts) -> void:
	if _curb == null:
		_curb = BoxMesh.new()
		_curb.size = Vector3(0.65, 0.18, 0.26)
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color("c9c1a4")
		stone.roughness = 0.95
		_curb.material = stone
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _curb
	mm.instance_count = 40
	var index := 0
	for side: float in [-1, 1]:
		for i in 10:
			mm.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(-4.05 + i * 0.9, 0.12, side * 4.5)))
			index += 1
			mm.set_instance_transform(index, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(side * 4.5, 0.12, -4.05 + i * 0.9)))
			index += 1
	var curb := MultiMeshInstance3D.new()
	curb.name = "StoneBorder"
	curb.multimesh = mm
	root.add_child(curb)
	if empty:
		var sign := Kit.new()
		sign.boxc(Vector3(0, 0.65, 0), Vector3(0.12, 1.3, 0.12), Color("755235"))
		sign.boxc(Vector3(0, 1.2, 0), Vector3(1.25, 0.65, 0.15), Color("a47b4f"))
		sign.boxc(Vector3(0, 1.2, 0.09), Vector3(0.1, 0.42, 0.025), Color("fff0c3"))
		sign.boxc(Vector3(0, 1.2, 0.09), Vector3(0.42, 0.1, 0.025), Color("fff0c3"))
		var node := MeshInstance3D.new()
		node.name = "BuildSign"
		node.mesh = sign.mesh()
		node.material_override = Kit.material(0.9)
		root.add_child(node)
	# Параметр пула оставлен для общего интерфейса деталей участка.
	assert(pool != null)


static func cauldron(root: Node3D) -> void:
	var kit := Kit.new()
	for x: float in [-0.8, 0.8]:
		kit.boxc(Vector3(x, 0.85, 1.1), Vector3(0.13, 1.7, 0.13), Color("6e5137"))
	kit.boxc(Vector3(0, 1.7, 1.1), Vector3(1.9, 0.13, 0.13), Color("6e5137"))
	var stand := MeshInstance3D.new()
	stand.mesh = kit.mesh()
	stand.material_override = Kit.material(0.9)
	root.add_child(stand)
	var pot := MeshInstance3D.new()
	pot.name = "Cauldron"
	var mesh := SphereMesh.new()
	mesh.radius = 0.65
	mesh.height = 0.85
	mesh.radial_segments = 12
	mesh.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("393b36")
	mat.roughness = 0.8
	mesh.material = mat
	pot.mesh = mesh
	pot.position = Vector3(0, 0.6, 1.1)
	root.add_child(pot)


static func river(world: Node3D, bounds: Rect2) -> void:
	var water := MeshInstance3D.new()
	water.name = "FortRiver"
	var plane := PlaneMesh.new()
	plane.size = Vector2(SPAN, 12)
	plane.subdivide_width = 100
	plane.subdivide_depth = 4
	water.mesh = plane
	water.position = Vector3(0, -0.25, bounds.position.y - 24)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/water.gdshader")
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(water)
