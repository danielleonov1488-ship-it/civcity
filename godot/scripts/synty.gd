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
	if name.begins_with("K:"):
		return KitLib.has(name)
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
		m.set_meta("alb", albedo)                     # какая картинка у поверхности (Parts: оттенок у экземпляра)
		# подкраска отдельной картинки (штукатурка дома в цвет), остальное — как есть
		var tints: Dictionary = remap.get("tints", {})
		if tints.has(albedo):
			m.albedo_color = tints[albedo]
		var ap := _tex_path(albedo)
		if ap != "":
			m.albedo_texture = Gfx.tex(ap)             # на «Очень низкой» — копия поменьше (scripts/gfx.gd)
		else:
			unknown["tex:" + albedo] = true
		# у общей палитры карта рельефа от другого набора — без неё палитра чище (как у Synty)
		var np := "" if normal.begins_with("PolygonAncientEmpire_") else _tex_path(normal)
		if np != "":
			m.normal_enabled = true
			m.normal_texture = Gfx.tex(np)
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
		m.albedo_texture = Gfx.tex(_tex_path("PolygonAncientEmpire_01_A"))
	if remap.has("tint"):
		m.albedo_color = remap["tint"]
	# листва деревьев и кустов (remap["leaf"], ставит make) — материал с временами года (shaders/foliage.gdshader,
	# scripts/seasons.gd); вечнозелёные (кипарисы, пальмы, оливы) осенью не желтеют и весной не цветут
	if remap.has("leaf") and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not m.normal_enabled and m.albedo_texture != null:
		var fm := ShaderMaterial.new()
		fm.shader = preload("res://shaders/foliage.gdshader")
		fm.set_shader_parameter("albedo_tex", m.albedo_texture)
		fm.set_shader_parameter("albedo", m.albedo_color)
		fm.set_shader_parameter("season", season_now)
		fm.set_shader_parameter("evergreen", remap["leaf"] == "ever")
		season_mats.append(fm)
		_mats[mkey] = fm
		return fm
	_mats[mkey] = m
	return m


## Материалы листвы с временами года и что на них сейчас (Seasons.apply)
static var season_mats: Array = []
static var season_on := false             # листва с временами года (ставит Game: только настоящая игра)
static var season_now := Vector4.ZERO


static func set_season(v: Vector4) -> void:
	season_now = v
	for fm: ShaderMaterial in season_mats:
		fm.set_shader_parameter("season", v)


## Узел с моделью name; материалы назначены, основание — на нуле (если ground)
const GREEN := Color(0.9, 0.93, 0.72)


static func make(name: String, remap := {}) -> Node3D:
	if name.begins_with("K:"):
		return KitLib.make(name, remap)                  # свой набор деталей (дома из Blender)
	_index()
	if remap.is_empty() and (name.begins_with("SM_Env_Tree") or name.begins_with("SM_Env_Bush") or name.begins_with("SM_Env_Garden")):
		remap = {"tint": GREEN}
	if season_on and name.begins_with("SM_Env_Tree") and remap.has("tint") and not remap.has("leaf"):
		remap = remap.duplicate()
		remap["leaf"] = "ever" if (name.contains("Thin") or name.contains("Palm") or remap.has("ever")) else "dec"
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
			var m := material(slot, remap)
			if m is StandardMaterial3D and (m as StandardMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED and _two_faced(mi.mesh, i):
				m = _cull_back(m as StandardMaterial3D)
			mi.set_surface_override_material(i, m)
	return n


## Листва «с изнанкой» (владелец 12.11: плющ на стенах местами чернеет): у части плетей Synty (Ivy_04–08, Ivy_01,
## свисающий плющ…) каждый лист — два треугольника, лицом наружу и лицом к стене, и у обоих нормаль наружу (так их
## делают для движков, где листва односторонняя). У нас листва двусторонняя (CULL_DISABLED): у второго треугольника
## Godot разворачивает нормаль — он смотрит в стену, тёмный, и спорит с первым на том же месте: чёрные пятна при
## одних углах солнца, при других нет. У таких поверхностей — свой материал с отсечением изнанки: виден ровно один
## лист, нормалью наружу. Поверхности, где лист один и нормаль по его лицу (Ivy_Flowers_01–03, лоза, ящики цветов),
## остаются двусторонними: у них Godot разворачивает нормаль правильно
static var _faced := {}
static func _two_faced(mesh: Mesh, s: int) -> bool:
	var k := "%d|%d" % [mesh.get_instance_id(), s]
	if _faced.has(k):
		return _faced[k]
	var ia := mesh.surface_get_arrays(s)
	var vs: PackedVector3Array = ia[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = ia[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = ia[Mesh.ARRAY_INDEX] if ia[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var cnt := 0
	var bad := 0
	var n_tri := (idx.size() if idx.size() > 0 else vs.size()) / 3
	if ns.size() == vs.size():
		for t in n_tri:
			var a := idx[t * 3] if idx.size() > 0 else t * 3
			var b := idx[t * 3 + 1] if idx.size() > 0 else t * 3 + 1
			var c := idx[t * 3 + 2] if idx.size() > 0 else t * 3 + 2
			var g := (vs[c] - vs[a]).cross(vs[b] - vs[a])       # лицо в Godot — обход по часовой
			if g.length_squared() < 1e-14:
				continue
			cnt += 1
			if g.dot(ns[a] + ns[b] + ns[c]) < 0.0:
				bad += 1
	var res := cnt > 0 and bad * 100 > cnt * 15
	_faced[k] = res
	return res


static func _cull_back(m: StandardMaterial3D) -> StandardMaterial3D:
	var k := "cullback|%d" % m.get_instance_id()
	if not _mats.has(k):
		var c := m.duplicate() as StandardMaterial3D
		c.cull_mode = BaseMaterial3D.CULL_BACK
		_mats[k] = c                               # в общем списке: «Очень низкая» подменяет картинки и у него
	return _mats[k]
