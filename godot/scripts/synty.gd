class_name Synty
extends RefCounted
## Модели Synty POLYGON Ancient Empire (куплено владельцем; лежат только локально, в git не попадают).
## В файлах моделей пути к текстурам — с чужих компьютеров, поэтому материалы назначаем сами:
## по списку MaterialList (слот материала → картинка) из набора.

const DIR := "res://assets/synty/"
static var _paths := {}          # имя модели → путь к FBX
static var _slots := {}          # слот материала → [albedo, normal]
static var _mesh_slots := {}     # модель → [[слот, albedo, normal], …] по порядку материалов
static var _tex := {}            # имя картинки → путь
static var _mats := {}           # слот → материал
static var _scenes := {}
static var unknown := {}         # слоты без картинки (для отладки)


static func _index() -> void:
	if not _paths.is_empty():
		return
	_scan(DIR + "FBX", ".fbx", _paths)
	_scan(DIR + "Textures", ".png", _tex)
	_scan(DIR + "Textures", ".tga", _tex)
	var f := FileAccess.open(DIR + "MaterialList_PolygonAncientEmpire.txt", FileAccess.READ)
	var slot := ""
	var mesh := ""
	var cur: Array = []
	while f and not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("Mesh Name:"):
			mesh = line.trim_prefix("Mesh Name:").strip_edges()
			if not _mesh_slots.has(mesh):
				_mesh_slots[mesh] = []
		elif line.begins_with("Slot:"):
			slot = line.trim_prefix("Slot:").strip_edges()
			if not _slots.has(slot):
				_slots[slot] = ["", ""]
			cur = [slot, "", ""]
			if mesh != "":
				_mesh_slots[mesh].append(cur)
		elif line.begins_with("Albedo:") and slot != "":
			var a := line.trim_prefix("Albedo:").strip_edges().split(" ")[0]
			cur[1] = a
			if _slots[slot][0] == "":
				_slots[slot][0] = a
		elif line.begins_with("Normal:") and slot != "":
			var nn := line.trim_prefix("Normal:").strip_edges().split(" ")[0]
			cur[2] = nn
			if _slots[slot][1] == "":
				_slots[slot][1] = nn


## ResourceLoader.list_directory, а не DirAccess: в собранной игре исходных .fbx/.png в файлах нет (только .import),
## а list_directory отдаёт привычные имена и там, и в редакторе
static func _scan(path: String, ext: String, out: Dictionary) -> void:
	var subs := []
	for f in ResourceLoader.list_directory(path):
		if f.ends_with("/"):
			subs.append(f.trim_suffix("/"))
		elif f.ends_with(ext):
			out[f.trim_suffix(ext)] = path + "/" + f
	for sub in subs:
		_scan(path + "/" + sub, ext, out)


## Имена картинок в списке материалов (из версии для Unity) и в исходниках отличаются — переводим
static func _tex_path(name: String) -> String:
	if name == "":
		return ""
	var cands := [name]
	var m := RegEx.create_from_string("^PolygonAncientEmpire_([0-9][0-9])_([A-C])$").search(name)
	if m:
		cands.append("PolygonAncientWorlds_Texture_%s_%s" % [m.get_string(1), m.get_string(2)])
	m = RegEx.create_from_string("^PolygonAncientEmpire_([0-9][0-9])_Normals$").search(name)
	if m:
		cands.append("PolygonAncientWorlds_Normal_%s" % m.get_string(1))
		cands.append("PolygonAncientWorlds_Normal_01")
	cands.append_array([name.replace("_01", "_Tex"), name.replace("_01", "_Texture_01"), name.trim_suffix("_01"), name.to_lower()])
	for c in cands:
		for k in _tex.keys():
			if k == c or k.to_lower() == String(c).to_lower():
				return _tex[k]
	return ""


static func has(name: String) -> bool:
	_index()
	return _paths.has(name)


static func names(prefix: String) -> Array:
	_index()
	var out := []
	for n in _paths.keys():
		if n.begins_with(prefix):
			out.append(n)
	out.sort()
	return out


## remap — подмена картинок: {"Stucco_White_01": "Stucco_Orange_01"} перекрашивает штукатурку дома;
## remap["tint"] — оттенок (деревья чуть зеленее палитры, ближе к уютной зелени Town to City)
static func material(slot: String, remap := {}) -> Material:
	var mkey := slot + "|" + str(remap)
	if _mats.has(mkey):
		return _mats[mkey]
	_index()
	var m := StandardMaterial3D.new()
	m.roughness = 0.85
	var key := slot
	if not _slots.has(key):
		# у импорта к имени иногда добавляется хвост «.001» — отрезаем
		key = slot.split(".")[0]
	if _slots.has(key):
		var albedo: String = _slots[key][0].get_basename()
		var normal: String = _slots[key][1].get_basename()
		albedo = remap.get(albedo, albedo)
		# подкраска отдельной картинки (штукатурка дома в цвет), остальное — как есть
		var tints: Dictionary = remap.get("tints", {})
		if tints.has(albedo):
			m.albedo_color = tints[albedo]
		var ap := _tex_path(albedo)
		if ap != "":
			m.albedo_texture = load(ap)
		else:
			unknown["tex:" + albedo] = true
		# у общей палитры карта рельефа от другого набора — без неё палитра чище (как у Synty)
		var np := "" if normal.begins_with("PolygonAncientEmpire_") else _tex_path(normal)
		if np != "":
			m.normal_enabled = true
			m.normal_texture = load(np)
			m.normal_scale = 0.6
		# решётки окон: просветы прозрачные — за ними тёмная комната, ночью у жилых домов тёплый свет
		if albedo.begins_with("Window"):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
		if slot.to_lower().contains("glass") or slot.to_lower().contains("water"):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.6
		if slot.to_lower().contains("leaf") or slot.to_lower().contains("ivy") or slot.to_lower().contains("plant") or slot.to_lower().contains("grass"):
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		unknown[slot] = true
		m.albedo_texture = load(_tex_path("PolygonAncientEmpire_01_A"))
	if remap.has("tint"):
		m.albedo_color = remap["tint"]
	_mats[mkey] = m
	return m


## Узел с моделью name; материалы назначены, основание — на нуле (если ground)
const GREEN := Color(0.9, 0.93, 0.72)


static func make(name: String, remap := {}) -> Node3D:
	_index()
	if remap.is_empty() and (name.begins_with("SM_Env_Tree") or name.begins_with("SM_Env_Bush") or name.begins_with("SM_Env_Garden")):
		remap = {"tint": GREEN}
	if not _paths.has(name):
		push_warning("Synty: нет модели " + name)
		return Node3D.new()
	if not _scenes.has(name):
		_scenes[name] = load(_paths[name])
	var n := (_scenes[name] as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		# материалы в файле модели называются по-своему — берём слоты из списка набора по порядку
		var list: Array = _mesh_slots.get(String(mi.name), _mesh_slots.get(name, []))
		for i in mi.mesh.get_surface_count():
			var slot := ""
			if i < list.size():
				slot = list[i][0]
			else:
				var src := mi.mesh.surface_get_material(i)
				slot = src.resource_name if src else ""
			mi.set_surface_override_material(i, material(slot, remap))
	return n
