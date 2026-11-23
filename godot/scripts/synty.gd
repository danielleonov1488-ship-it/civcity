class_name Synty
extends RefCounted

const Perf14 = preload("res://scripts/perf14_timers.gd")
## Модели Synty POLYGON Ancient Empire (куплено владельцем; лежат только локально, в git не попадают).
## В файлах моделей пути к текстурам — с чужих компьютеров, поэтому материалы назначаем сами:
## по списку MaterialList (слот материала → картинка) из набора.

const DIR := "res://assets/synty/"
static var _paths := {}          # имя модели → путь к FBX
static var _slots := {}          # слот материала → [albedo, normal]
static var _mesh_slots := {}     # модель → [[слот, albedo, normal], …] по порядку материалов
static var _tex := {}            # имя картинки → путь
static var _texture_names := {}
static var _mats := {}           # слот → материал
static var _scenes := {}
static var unknown := {}         # слоты без картинки (для отладки)


static func _index() -> void:
	if not _paths.is_empty():
		return
	_install_index(_read_index())


## Собираем индекс в своих словарях. Общий индекс отдаём целиком.
static func _read_index() -> Array[Dictionary]:
	var paths := {}
	var textures := {}
	var slots := {}
	var mesh_slots := {}
	_scan(DIR + "FBX", ".fbx", paths)
	_scan(DIR + "Textures", ".png", textures)
	_scan(DIR + "Textures", ".tga", textures)
	var tex := {}
	for name: String in textures:
		var lower := name.to_lower()
		if not tex.has(lower):
			tex[lower] = textures[name]
	var f := FileAccess.open(DIR + "MaterialList_PolygonAncientEmpire.txt", FileAccess.READ)
	var slot := ""
	var mesh := ""
	var cur: Array = []
	while f and not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("Mesh Name:"):
			mesh = line.trim_prefix("Mesh Name:").strip_edges()
			if not mesh_slots.has(mesh):
				mesh_slots[mesh] = []
		elif line.begins_with("Slot:"):
			slot = line.trim_prefix("Slot:").strip_edges()
			if not slots.has(slot):
				slots[slot] = ["", ""]
			cur = [slot, "", ""]
			if mesh != "":
				mesh_slots[mesh].append(cur)
		elif line.begins_with("Albedo:") and slot != "":
			var a := line.trim_prefix("Albedo:").strip_edges().split(" ")[0]
			cur[1] = a
			if slots[slot][0] == "":
				slots[slot][0] = a
		elif line.begins_with("Normal:") and slot != "":
			var nn := line.trim_prefix("Normal:").strip_edges().split(" ")[0]
			cur[2] = nn
			if slots[slot][1] == "":
				slots[slot][1] = nn
	return [paths, tex, slots, mesh_slots]


static func _install_index(index: Array[Dictionary]) -> void:
	if not _paths.is_empty():
		return
	_paths = index[0]
	_tex = index[1]
	_slots = index[2]
	_mesh_slots = index[3]


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
	if _texture_names.has(name):
		return _texture_names[name]
	var cands := [name]
	var m := RegEx.create_from_string("^PolygonAncientEmpire_([0-9][0-9])_([A-C])$").search(name)
	if m:
		cands.append("PolygonAncientWorlds_Texture_%s_%s" % [m.get_string(1), m.get_string(2)])
	m = RegEx.create_from_string("^PolygonAncientEmpire_([0-9][0-9])_Normals$").search(name)
	if m:
		cands.append("PolygonAncientWorlds_Normal_%s" % m.get_string(1))
		cands.append("PolygonAncientWorlds_Normal_01")
	cands.append_array([name.replace("_01", "_Tex"), name.replace("_01", "_Texture_01"), name.trim_suffix("_01"), name.to_lower()])
	for c: String in cands:
		var lower := c.to_lower()
		if _tex.has(lower):
			_texture_names[name] = _tex[lower]
			return _tex[lower]
	if not _tex.is_empty():
		_texture_names[name] = ""
	return ""


static func has(name: String) -> bool:
	if name.begins_with("K:"):
		return KitLib.has(name)
	if name.begins_with("M:"):
		return Meadow.has(name)                   # набор Meadow Forest (scripts/meadow.gd)
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
static func texture_paths(name: String, remap: Dictionary, paths: Dictionary) -> void:
	var slots: Array = _mesh_slots.get(name, _mesh_slots.get(name + "_LOD0", []))
	for entry: Array in slots:
		var slot: String = entry[0]
		var pair: Array = _slots.get(slot, entry.slice(1))
		var albedo: String = String(pair[0]).get_basename()
		var path := _tex_path(String(remap.get(albedo, albedo)))
		if path != "":
			paths[path] = true
		var normal: String = String(pair[1]).get_basename()
		if not normal.begins_with("PolygonAncientEmpire_") and normal != "":
			path = _tex_path(normal)
			if path != "":
				paths[path] = true


static func _material_texture(path: String) -> Texture2D:
	if not Gfx._tex_small:
		var cached := ResourceLoader.get_cached_ref(path) as Texture2D
		if cached != null:
			return cached
	var started := Perf14.begin()
	var texture := Gfx.tex(path)
	Perf14.loaded(path, started)
	return texture


static func material(slot: String, remap := {}) -> Material:
	var started := Perf14.begin()
	var value := material_profiled(slot, remap)
	Perf14.end(Perf14.MATERIAL, started)
	return value


static func material_profiled(slot: String, remap := {}) -> Material:
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
			m.albedo_texture = _material_texture(ap)             # на «Очень низкой» — копия поменьше (scripts/gfx.gd)
		else:
			unknown["tex:" + albedo] = true
		# у общей палитры карта рельефа от другого набора — без неё палитра чище (как у Synty)
		var np := "" if normal.begins_with("PolygonAncientEmpire_") else _tex_path(normal)
		if np != "":
			m.normal_enabled = true
			m.normal_texture = _material_texture(np)
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


static func make(name: String, remap := {}, geometry_only := false) -> Node3D:
	if name.begins_with("K:"):
		return KitLib.make(name, remap)                  # свой набор деталей (дома из Blender)
	if name.begins_with("M:"):
		return Meadow.make(name, remap)                  # луга и рощи Meadow Forest (scripts/meadow.gd)
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
		var loading := Perf14.begin()
		_scenes[name] = load(_paths[name])
		Perf14.loaded(_paths[name], loading)
	var n := (_scenes[name] as PackedScene).instantiate() as Node3D
	if geometry_only:
		return n
	var open_bridge := bool(remap.get("open_bridge", false))
	if open_bridge:
		remap = remap.duplicate()
		remap.erase("open_bridge")
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if open_bridge:
			mi.mesh = _open_bridge_arch(mi.mesh)
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
			if m is StandardMaterial3D and (m as StandardMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED and _two_faced(mi.mesh, i, name + "|" + String(n.get_path_to(mi)) + "|" + str(open_bridge)):
				m = _cull_back(m as StandardMaterial3D)
			mi.set_surface_override_material(i, m)
	return n


## У мостов оставляем каменную рамку, снимаем вставки над дверью, перекладину и средник.
static var _bridge_arch: ArrayMesh


static func _open_bridge_arch(source: Mesh) -> ArrayMesh:
	if _bridge_arch != null:
		return _bridge_arch
	_bridge_arch = ArrayMesh.new()
	for s in source.get_surface_count():
		var data := source.surface_get_arrays(s)
		var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for i in range(0, indices.size(), 3):
			var a := vertices[indices[i]]
			var b := vertices[indices[i + 1]]
			var c := vertices[indices[i + 2]]
			var lo := a.min(b).min(c)
			var hi := a.max(b).max(c)
			var panel := lo.x > 0.38 and hi.x < 2.12 and lo.y > 2.145 and hi.y < 2.561 \
				and lo.z > -0.116 and hi.z < 0.116
			var crossbar := lo.x > 0.19 and hi.x < 2.31 and lo.y > 1.965 and hi.y < 2.15 \
				and hi.x > 0.37 and lo.x < 2.13
			var divider := lo.x > 1.20 and hi.x < 1.30 and lo.y > 2.12 and hi.y < 2.56
			if not (panel or crossbar or divider):
				kept.append_array([indices[i], indices[i + 1], indices[i + 2]])
		data[Mesh.ARRAY_INDEX] = kept
		_bridge_arch.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
		_bridge_arch.surface_set_material(s, source.surface_get_material(s))
	return _bridge_arch


## Листва «с изнанкой» (владелец 12.11: плющ на стенах местами чернеет): у части плетей Synty (Ivy_04–08, Ivy_01,
## свисающий плющ…) каждый лист — два треугольника, лицом наружу и лицом к стене, и у обоих нормаль наружу (так их
## делают для движков, где листва односторонняя). У нас листва двусторонняя (CULL_DISABLED): у второго треугольника
## Godot разворачивает нормаль — он смотрит в стену, тёмный, и спорит с первым на том же месте: чёрные пятна при
## одних углах солнца, при других нет. У таких поверхностей — свой материал с отсечением изнанки: виден ровно один
## лист, нормалью наружу. Поверхности, где лист один и нормаль по его лицу (Ivy_Flowers_01–03, лоза, ящики цветов),
## остаются двусторонними: у них Godot разворачивает нормаль правильно
static var _faced := {}
static func _two_faced(mesh: Mesh, s: int, source: String) -> bool:
	var k := "%s|%d" % [source, s]
	if _faced.has(k):
		return _faced[k]
	var started := Perf14.begin()
	var ia := mesh.surface_get_arrays(s)
	Perf14.end(Perf14.MESH_READ, started)
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
