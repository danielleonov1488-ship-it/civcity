class_name Parts
extends Node3D
## Пул деталей: все одинаковые детали Synty (одной раскраски) по всему городу рисуются одним MultiMesh.
## place(чертёж, где) возвращает ручку; remove(ручка) убирает детали этой постройки.
## Свободные места переиспользуются, буфер растёт удвоением.

var groups := {}          # ключ → {subs: [{mm, mmi, local}], free: [], used: int, cap: int}
static var _special := {}


func _group(name: String, remap: Dictionary, tile := Vector2i(-1, -1)) -> Dictionary:
	var key := name + "|" + str(remap) + ("" if tile.x < 0 else "|%d,%d" % [tile.x, tile.y])
	if groups.has(key):
		return groups[key]
	var g := {"subs": [], "free": [], "used": 0, "cap": 0, "key": key}
	if name.begins_with("#"):
		g["subs"].append(_sub(_special_mesh(name), Transform3D.IDENTITY))
	else:
		var src := Synty.make(name, remap)
		for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
			var mesh := mi.mesh.duplicate() as Mesh
			for s in mesh.get_surface_count():
				var m := mi.get_surface_override_material(s)
				if m:
					mesh.surface_set_material(s, m)
			var sub := _sub(mesh, Citizen._rel(mi, src))
			# мелочь (трава, цветы, кувшинки, камешки) — без тени и только вблизи: так быстрее
			if name.contains("Grass") or name.contains("Flowers") or name.contains("Lillies") or name.contains("Pebbles") or name.contains("Garden_Plants"):
				var mmi: MultiMeshInstance3D = sub["mmi"]
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if tile.x >= 0:
					mmi.visibility_range_end = 150.0
					mmi.visibility_range_end_margin = 20.0
					mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			g["subs"].append(sub)
		src.free()
	groups[key] = g
	return g


func _sub(mesh: Mesh, local: Transform3D) -> Dictionary:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return {"mm": mm, "mmi": mmi, "local": local}


static func _special_mesh(name: String) -> Mesh:
	if _special.has(name):
		return _special[name]
	if name.begins_with("#mil_"):                  # палатки, мишени, баллисты… Легиона (cat_military.gd)
		_special[name] = CatMilitary.kit_mesh(name)
		return _special[name]
	var bm := BoxMesh.new()
	var m := StandardMaterial3D.new()
	match name:
		"#dark":
			m.albedo_color = Color("2a2019")
			m.roughness = 1.0
		"#lit":
			# жилой дом и лавка изнутри: ночью в окнах — еле тёплый огонёк (как от спички), светят фонари, а не дома
			m.albedo_color = Color("2e2218")
			m.roughness = 1.0
			m.emission_enabled = true
			m.emission = Color("ffa04a")
			m.emission_energy_multiplier = 0.0
		"#ember":
			# угли и пламя в жаровнях, факелах, огненных чашах: днём тёмные, ночью горят ярко
			m.albedo_color = Color("2e2218")
			m.roughness = 1.0
			m.emission_enabled = true
			m.emission = Color("ffb35c")
			m.emission_energy_multiplier = 0.0
		"#marble":
			m = Synty.material("Marble_01").duplicate()
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.4, 0.4, 0.4)
		"#water":
			m.albedo_color = Color(0.32, 0.72, 0.74, 0.85)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.08
			m.metallic_specular = 0.7
		"#duck", "#swan":
			var am := _bird_mesh(name == "#swan")
			_special[name] = am
			return am
		"#lamp_post", "#wall_lamp", "#wall_lamp_dim":
			# #wall_lamp_dim — фонарик у двери жилого дома: ночью еле теплится (улицу светят фонари-украшения)
			var lm := _lamp_mesh(name != "#lamp_post", name == "#wall_lamp_dim")
			_special[name] = lm
			return lm
		"#shutters_green", "#shutters_brown", "#shutters_blue", "#window_box", "#chimney":
			var km := _small_mesh(name)
			_special[name] = km
			return km
		_:
			m.albedo_color = Color.MAGENTA
	bm.material = m
	_special[name] = bm
	return bm


## Мелочи, которых нет в Synty, но они есть у домов Town to City (в палитре Synty):
## ставни (пара, раскрыты к стене; середина окна — начало координат, лицом к +Z), ящик с цветами под окном, печная труба
static func _small_mesh(name: String) -> Mesh:
	var k := Kit.new()
	match name:
		"#shutters_green", "#shutters_brown", "#shutters_blue":
			var col: Color = {"#shutters_green": Color("5d8a48"), "#shutters_brown": Color("7a4e2c"), "#shutters_blue": Color("4f7c9a")}[name]
			for sx: float in [-1.0, 1.0]:
				var cx := sx * 0.8
				k.boxc(Vector3(cx, 0.0, 0.03), Vector3(0.46, 1.08, 0.05), col, [])
				# планки и рамка чуть темнее — объём как у кубиков Town to City
				for j in 5:
					k.boxc(Vector3(cx, -0.4 + j * 0.2, 0.065), Vector3(0.4, 0.05, 0.03), col.darkened(0.18), [])
				k.boxc(Vector3(cx, 0.0, 0.07), Vector3(0.05, 1.0, 0.025), col.darkened(0.25), [])
		"#window_box":
			k.boxc(Vector3(0, 0.08, 0.1), Vector3(0.9, 0.16, 0.2), Color("b5603a"), [])
			k.boxc(Vector3(0, 0.0, 0.1), Vector3(0.94, 0.03, 0.24), Color("8f4a2c"), [])
			var cols := [Color("c8384a"), Color("e88aa0"), Color("f0e2c8"), Color("d9502e"), Color("e8b13a")]
			for i in 9:
				var x := -0.38 + i * 0.095
				k.boxc(Vector3(x, 0.2, 0.1 + (0.04 if i % 2 else -0.04)), Vector3(0.11, 0.1, 0.11), Color("4f7a2e").darkened(0.1 * (i % 3)), [])
				if i % 2 == 0:
					k.boxc(Vector3(x, 0.28, 0.1), Vector3(0.07, 0.07, 0.07), cols[i % cols.size()], [])
		"#chimney":
			k.boxc(Vector3(0, 0.55, 0), Vector3(0.46, 1.1, 0.46), Color("e9dfcb"))
			k.boxc(Vector3(0, 1.12, 0), Vector3(0.6, 0.08, 0.6), Color("b5603a"), [])
			k.boxc(Vector3(0, 1.2, 0), Vector3(0.36, 0.08, 0.36), Color("8f4a2c"), [])
			k.boxc(Vector3(0, 1.245, 0), Vector3(0.22, 0.01, 0.22), Color("1c1410"), [])
	var m := k.mesh()
	m.surface_set_material(0, Kit.material(0.85))
	return m


## Римский фонарь: бронзовый корпус, тёплые стёкла (светятся ночью вместе с окнами домов)
static func _lamp_mesh(wall: bool, dim := false) -> Mesh:
	var k := Kit.new()
	var glass := Kit.new()
	var wood := Color("5a3b22")
	var bronze := Color("9a6a2c")
	var stone := Color("cfc3ad")
	var lx := 0.0
	var ly := 0.0
	var lz := 0.0
	if wall:
		# кронштейн из стены и фонарь на цепочке
		k.boxc(Vector3(0, 0.0, 0.03), Vector3(0.12, 0.2, 0.06), bronze)
		k.rod(Vector3(0, 0.0, 0.05), Vector3(0, 0.0, 0.42), 0.018, 5, bronze)
		k.rod(Vector3(0, 0.0, 0.42), Vector3(0, -0.12, 0.42), 0.008, 4, Color("3a2a1a"))
		lx = 0.0
		ly = -0.2
		lz = 0.42
	else:
		k.boxc(Vector3(0, 0.15, 0), Vector3(0.34, 0.3, 0.34), stone, [])
		k.cyl(Vector3(0, 0.3, 0), 0.07, 2.0, 6, wood)
		k.rod(Vector3(0, 2.25, 0), Vector3(0.45, 2.25, 0), 0.03, 5, wood)
		k.rod(Vector3(0.42, 2.25, 0), Vector3(0.42, 2.17, 0), 0.008, 4, Color("3a2a1a"))
		k.cone(Vector3(0, 2.3, 0), 0.06, 0.12, 6, bronze)
		lx = 0.42
		ly = 2.07
		lz = 0.0
	# корпус фонаря: крышка, рамка, донце
	k.cone(Vector3(lx, ly + 0.1, lz), 0.13, 0.12, 4, bronze)
	k.boxc(Vector3(lx, ly - 0.12, lz), Vector3(0.2, 0.03, 0.2), bronze, [])
	for c: Vector2 in [Vector2(-0.085, -0.085), Vector2(0.085, -0.085), Vector2(-0.085, 0.085), Vector2(0.085, 0.085)]:
		k.boxc(Vector3(lx + c.x, ly - 0.01, lz + c.y), Vector3(0.025, 0.2, 0.025), bronze, [])
	glass.boxc(Vector3(lx, ly - 0.01, lz), Vector3(0.16, 0.18, 0.16), Color("ffd48a"), [])
	var m := k.mesh()
	m.surface_set_material(0, Kit.material(0.6))
	var g := glass.mesh()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, g.surface_get_arrays(0))
	m.surface_set_material(1, _glass_dim_material() if dim else _glass_material())
	return m


static var _glass: StandardMaterial3D
static var _glass_dim: StandardMaterial3D


## Стекло фонарика у двери жилого дома: то же стекло, но ночью светится еле-еле (яркость меняет игра)
static func _glass_dim_material() -> StandardMaterial3D:
	if _glass_dim == null:
		_glass_dim = _glass_material().duplicate()
		_glass_dim.emission_energy_multiplier = 0.0
	return _glass_dim


## Стекло фонарей: днём просто тёплое, ночью светится (яркость меняет игра вместе с окнами)
static func _glass_material() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = Color("f3d49a")
		_glass.vertex_color_use_as_albedo = false
		_glass.emission_enabled = true
		_glass.emission = Color("ffb35c")
		_glass.emission_energy_multiplier = 0.0
		_glass.roughness = 0.3
	return _glass


## Утка и лебедь на воде — низкополигональные, в духе Synty
static func _bird_mesh(swan: bool) -> Mesh:
	var k := Kit.new()
	if swan:
		var w := Color("f4f1ea")
		k.blob(Vector3(0, 0.14, 0), Vector3(0.36, 0.2, 0.62), w, 3, 0.08)
		k.blob(Vector3(0, 0.24, -0.16), Vector3(0.3, 0.14, 0.34), w, 5, 0.1)
		k.rod(Vector3(0, 0.2, 0.22), Vector3(0, 0.46, 0.3), 0.045, 6, w)
		k.rod(Vector3(0, 0.46, 0.3), Vector3(0, 0.6, 0.26), 0.04, 6, w)
		k.blob(Vector3(0, 0.62, 0.3), Vector3(0.08, 0.08, 0.12), w, 7, 0.05)
		k.boxc(Vector3(0, 0.61, 0.39), Vector3(0.035, 0.03, 0.08), Color("e0782a"))
		k.boxc(Vector3(0, 0.625, 0.345), Vector3(0.05, 0.035, 0.03), Color("2a2522"))
	else:
		var br := Color("8a6a46")
		k.blob(Vector3(0, 0.07, 0), Vector3(0.16, 0.1, 0.28), br, 2, 0.08)
		k.boxc(Vector3(0, 0.1, -0.13), Vector3(0.06, 0.05, 0.08), Color("3d3a35"))
		k.blob(Vector3(0, 0.17, 0.12), Vector3(0.08, 0.08, 0.09), Color("2f6a3e"), 4, 0.05)
		k.boxc(Vector3(0, 0.16, 0.18), Vector3(0.035, 0.02, 0.06), Color("e8a33a"))
		k.boxc(Vector3(0, 0.13, 0.1), Vector3(0.08, 0.015, 0.02), Color("f1ede4"))
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.7))
	return am


func _grow(g: Dictionary) -> void:
	var cap: int = maxi(16, int(g["cap"]) * 2)
	for sub in g["subs"]:
		var mm: MultiMesh = sub["mm"]
		var old := mm.buffer
		mm.instance_count = cap
		var buf := mm.buffer
		for i in old.size():
			buf[i] = old[i]
		# новые места — пустые (нулевой масштаб)
		for i in range(old.size(), buf.size()):
			buf[i] = 0.0
		mm.buffer = buf
	g["cap"] = cap


func _alloc(g: Dictionary) -> int:
	var free: Array = g["free"]
	if not free.is_empty():
		return free.pop_back()
	if int(g["used"]) >= int(g["cap"]):
		_grow(g)
	var i: int = g["used"]
	g["used"] = i + 1
	for sub in g["subs"]:
		(sub["mm"] as MultiMesh).visible_instance_count = i + 1
	return i


## Поставить чертёж; xf — где стоит постройка. Возвращает ручку [[группа, место], …]
func place(bp: Bp, xf: Transform3D, subst := {}) -> Array:
	var handles := []
	for p in bp.parts:
		var g := _group(subst.get(p[0], p[0]), p[2])
		var slot := _alloc(g)
		var t: Transform3D = xf * (p[1] as Transform3D)
		for sub in g["subs"]:
			(sub["mm"] as MultiMesh).set_instance_transform(slot, t * (sub["local"] as Transform3D))
		handles.append([g, slot])
	return handles


## Одна деталь; tiled — природа: кусками по 48 м, чтобы невидимые куски не рисовались
func place_one(name: String, xf: Transform3D, remap := {}, tiled := false) -> Array:
	var g := _group(name, remap, Vector2i(int(xf.origin.x / 48.0), int(xf.origin.z / 48.0)) if tiled else Vector2i(-1, -1))
	var slot := _alloc(g)
	for sub in g["subs"]:
		(sub["mm"] as MultiMesh).set_instance_transform(slot, xf * (sub["local"] as Transform3D))
	return [[g, slot]]


func remove(handles: Array) -> void:
	var zero := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -100, 0))
	for h in handles:
		var g: Dictionary = h[0]
		var slot: int = h[1]
		for sub in g["subs"]:
			(sub["mm"] as MultiMesh).set_instance_transform(slot, zero)
		(g["free"] as Array).append(slot)


func count() -> int:
	var n := 0
	for k in groups:
		n += int(groups[k]["used"]) - (groups[k]["free"] as Array).size()
	return n


static var _tint_shader: Shader
static var _outline_shader: Shader


static func tint_material(col: Color, grow := 0.0) -> ShaderMaterial:
	if _tint_shader == null:
		_tint_shader = load("res://shaders/tint.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _tint_shader
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("grow", grow)
	return m


static func outline_material(col := Color(1.0, 0.97, 0.88), width := 0.07) -> ShaderMaterial:
	if _outline_shader == null:
		_outline_shader = load("res://shaders/outline.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _outline_shader
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("width", width)
	return m


## Модель постройки отдельными узлами. mode: "place" — как есть, сверху цветная пелена (overlay);
## "shell" — только цветная оболочка (подсветка существующей постройки); "outline" — обводка по силуэту
static func ghost(bp: Bp, mode := "place", col := Color(0.4, 0.9, 0.4, 0.4)) -> Node3D:
	var root := Node3D.new()
	for p in bp.parts:
		var n: Node3D
		if (p[0] as String).begins_with("#"):
			var mi := MeshInstance3D.new()
			mi.mesh = _special_mesh(p[0])
			n = mi
		else:
			n = Synty.make(p[0], p[2])
		n.transform = p[1]
		root.add_child(n)
	var mat: Material
	match mode:
		"shell": mat = tint_material(col, 0.03)
		"outline": mat = outline_material(col)
		_: mat = tint_material(col, 0.005)
	for mi: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mode == "place":
			mi.material_overlay = mat
		else:
			mi.material_override = mat
	root.set_meta("mat", mat)
	return root


static func ghost_color(g: Node3D, col: Color) -> void:
	var m: ShaderMaterial = g.get_meta("mat")
	if m and m.shader == _tint_shader:
		m.set_shader_parameter("tint", col)
