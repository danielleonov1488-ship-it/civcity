class_name KitLib
extends RefCounted
## Свой набор деталей CivCity (Blender: deploy/kit/kit_houses.py) — дома и общие створки (ставни, двери).
## В чертежах детали зовутся "K:<файл>/<узел>": "K:pleb_0_2/House", "K:pleb_0_2/Walls", "K:common/sh_green_33_72_L".
## Synty.make / Synty.has / Bp.model_aabb отдают такие имена сюда. Материалы из .glb подменяются общими (по имени):
## CivKit — цвет вершин; CivPlaster — цвет вершин × рисованная штукатурка × цвет дома (remap "tint");
## CivEmber — угольки очага; NoticeMat / FriezeMat — роспись. "@lit" в конце имени — комната ночью тепло светится.

const DIR := "res://assets/kit/houses/"
const TEX := "res://assets/kit/tex/"

static var _meta := {}
static var _scenes := {}
static var _meshes := {}             # "файл/узел" → Mesh (с общими материалами)
static var _mats := {}               # имя → общий материал
static var _tints := {}              # цвет → штукатурка этого цвета


static func meta() -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open(DIR + "kit.json", FileAccess.READ)
		if f:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				_meta = j
		if _meta.is_empty():
			_meta = {"houses": {}, "common": []}
	return _meta


static func house(id: String) -> Dictionary:
	return (meta().get("houses", {}) as Dictionary).get(id, {})


static func has(name: String) -> bool:
	return _mesh(name) != null


## Узел с сеткой детали (как у Synty.make — Parts берёт из него MeshInstance3D)
static func make(name: String, remap := {}) -> Node3D:
	var root := Node3D.new()
	var mesh := _mesh(name)
	if mesh == null:
		push_warning("KitLib: нет детали " + name)
		return root
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if remap.has("tint"):
		for s in mesh.get_surface_count():
			if mesh.surface_get_material(s) == _mat("CivPlaster"):
				mi.set_surface_override_material(s, plaster(remap["tint"]))
	root.add_child(mi)
	return root


## Штукатурка цвета дома
static func plaster(c: Color) -> Material:
	var k := c.to_html()
	if not _tints.has(k):
		var m := (_mat("CivPlaster") as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.albedo_color = c
		_tints[k] = m
	return _tints[k]


## Свет в комнатах ночью: яркость меняет игра (Game._sky, вместе с окнами «#lit»)
static func lit_material() -> StandardMaterial3D:
	return _mat("CivKitLit") as StandardMaterial3D


static func _mat(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	match name:
		"CivPlaster":
			m.albedo_texture = load(TEX + "plaster_mul.png")
			m.roughness = 0.9
		"CivEmber":
			m.emission_enabled = true
			m.emission = Color("ff8a2e")
			m.emission_energy_multiplier = 1.4
		"CivKitLit":
			m.emission_enabled = true
			m.emission = Color("ffa04a")
			m.emission_energy_multiplier = 0.0
		"NoticeMat":
			m.vertex_color_use_as_albedo = false
			m.albedo_texture = load(TEX + "notice.png")
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.35
			m.roughness = 0.9
		"FriezeMat":
			m.vertex_color_use_as_albedo = false
			m.albedo_texture = load(TEX + "meander.png")
			m.roughness = 0.9
	_mats[name] = m
	return m


static func _mesh(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var body := name.substr(2) if name.begins_with("K:") else name
	var lit := body.ends_with("@lit")
	if lit:
		body = body.substr(0, body.length() - 4)
	var cut := body.find("/")
	if cut < 0:
		return null
	var file := body.substr(0, cut)
	var node := body.substr(cut + 1)
	if not _scenes.has(file):
		var path := DIR + file + ".glb"
		_scenes[file] = load(path) if ResourceLoader.exists(path) else null
	var ps: PackedScene = _scenes[file]
	if ps == null:
		_meshes[name] = null
		return null
	var inst := ps.instantiate()
	var found: MeshInstance3D = null
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) == node or String(mi.get_parent().name) == node:
			found = mi
			break
	var out: Mesh = null
	if found:
		out = found.mesh.duplicate() as Mesh
		for s in out.get_surface_count():
			var src := out.surface_get_material(s)
			var nm := src.resource_name if src else "CivKit"
			if lit and nm == "CivKit":
				nm = "CivKitLit"
			out.surface_set_material(s, _mat(nm))
	inst.free()
	_meshes[name] = out
	return out
