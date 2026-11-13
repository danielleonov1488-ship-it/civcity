class_name Meadow
extends RefCounted
## Модели Synty POLYGON Meadow Forest (куплено владельцем 13.11; лежат только локально — assets/synty_meadow, в git
## не попадают): деревья (берёзы, луговые, фруктовые), кусты, трава, полевые цветы, рапс, подсолнухи, кувшинки, камни,
## каменные ограды, мельницы, мостик. Имя модели в игре — с приставкой «M:» (M:SM_Env_Tree_Birch_01): у двух наборов
## есть одинаковые имена (кувшинки, скалы). «@n» в конце — какая ступень детализации из файла (M:…_Patch_01@1).
## Материалы — по списку набора (MaterialList_PNB_Meadow_Forest.txt), как у Synty.gd; у набора свой ветер и листва
## в шейдерах Unity — здесь свои: shaders/meadow_foliage.gdshader (лист/ствол по цвету вершин, качание по ветру,
## времена года) и shaders/meadow_rock.gdshader (камень сбоку, трава сверху).

const DIR := "res://assets/synty_meadow/"
const PREFIX := "M:"
static var _paths := {}           # имя модели → путь к FBX
static var _tex := {}             # имя картинки (без расширения) → путь
static var _mesh_slots := {}      # имя сетки → [{slot, Albedo, _Leaf_Texture, …}, …] по порядку поверхностей
static var _mats := {}
static var _scenes := {}
static var on := true             # набор есть (в собранной игре без него — Meadow.has() ложь, природа как прежде)

## Какая ступень детализации из файла: у деревьев набора листва — тысячи карточек (берёза 18 тыс. вершин на LOD0),
## а камера города далеко — берём LOD1/LOD2 (вид тот же, в 4–8 раз легче). Остальное — LOD0
const LOD := {
	"SM_Env_Tree_Birch_01": 2, "SM_Env_Tree_Birch_02": 2, "SM_Env_Tree_Birch_03": 1,
	"SM_Env_Tree_Meadow_01": 2, "SM_Env_Tree_Meadow_02": 2,
	"SM_Env_Tree_Fruit_01": 1, "SM_Env_Tree_Fruit_02": 1, "SM_Env_Tree_Fruit_03": 1,
	"SM_Env_Bush_01": 1, "SM_Env_Bush_03": 2,
	"SM_Env_Wildflowers_01": 2, "SM_Env_Wildflowers_02": 2, "SM_Env_Wildflowers_03": 2,
	"SM_Env_Lillies_01": 1, "SM_Env_Lillies_02": 1, "SM_Env_Lillies_03": 1, "SM_Env_Grass_Bush_01": 1,
	"SM_Env_Wildflowers_Patch_01": 1, "SM_Env_Wildflowers_Patch_02": 1, "SM_Env_Wildflowers_Patch_03": 1,
	"SM_Env_Sunflower_01": 1,
	"SM_Prop_StoneWall_01": 2, "SM_Prop_StoneWall_02": 2, "SM_Prop_Stonewall_Long_01": 2,
}

## Оттенки (sRGB, множатся на картинку): листва набора светлее и желтее нашей палитры — к уютной зелени города
const LEAF_TINT := Color(1, 1, 1)
const GRASS_TINT := Color(0.86, 0.9, 0.74)
const TRUNK_TINT := Color(0.92, 0.9, 0.86)
## Листва деревьев и кустов — к одному среднему цвету (линейному): солнечная жёлто-зелёная, как у олив и кипарисов
## Ancient Empire в нашем свете (владелец и ревью 13.11: луговые деревья читались почти чёрными пятнами). Средние цвета
## картинок (по непрозрачным точкам, линейные) — посчитаны заранее (.work/nature)
const LEAF_TARGET := Vector3(0.2, 0.27, 0.06)
const LEAF_AVG := {"leafPatch_01": Vector3(0.2594, 0.3554, 0.1465), "leafPatch_04": Vector3(0.0474, 0.0683, 0.0091),
	"Branches_01": Vector3(0.0614, 0.0434, 0.0229), "Branches_02": Vector3(0.3096, 0.2911, 0.28)}
const BRANCH_TARGET := Vector3(0.16, 0.12, 0.08)


static func _index() -> void:
	if not _paths.is_empty() or not on:
		return
	if OS.get_environment("CIVCITY_MEADOW") == "0":
		on = false                                # сравнение «без набора» (замеры скорости A/B)
		return
	if not DirAccess.dir_exists_absolute(DIR) and ResourceLoader.list_directory(DIR).is_empty():
		on = false
		return
	Synty._scan(DIR + "FBX", ".fbx", _paths)
	Synty._scan(DIR + "Textures", ".png", _tex)
	Synty._scan(DIR + "Textures", ".tga", _tex)
	if _paths.is_empty():
		on = false
		return
	var f := FileAccess.open(DIR + "MaterialList_PNB_Meadow_Forest.txt", FileAccess.READ)
	var mesh := ""
	var cur := {}
	while f and not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("Mesh Name:"):
			mesh = line.trim_prefix("Mesh Name:").strip_edges()
			if not _mesh_slots.has(mesh):
				_mesh_slots[mesh] = []
		elif line.begins_with("Slot:"):
			cur = {"slot": line.trim_prefix("Slot:").strip_edges()}
			if mesh != "":
				_mesh_slots[mesh].append(cur)
		elif line.contains(":") and line.contains("(") and not cur.is_empty():
			var key := line.split(":")[0].strip_edges()
			var val := line.split(":", true, 1)[1].strip_edges().split(" (")[0].strip_edges()
			cur[key] = val.get_basename()


static func has(name: String) -> bool:
	_index()
	return on and _paths.has(_base(name))


static func names(prefix: String) -> Array:
	_index()
	var out := []
	for n in _paths.keys():
		if n.begins_with(prefix):
			out.append(PREFIX + n)
	out.sort()
	return out


## Имя модели в файлах: без «M:» и «@ступени»
static func _base(name: String) -> String:
	return name.trim_prefix(PREFIX).split("@")[0]


static func _lod_of(name: String) -> int:
	var s := name.trim_prefix(PREFIX)
	if s.contains("@"):
		return int(s.split("@")[1])
	return int(LOD.get(_base(name), 0))


## Мелочь (трава, цветы, кувшинки, поля): без тени и только вблизи (Parts._small)
static func small(name: String) -> bool:
	if not name.begins_with(PREFIX):
		return false
	for k in ["Grass", "Flowers", "flowers", "Lillies", "Ground_Cover", "Rock_Small"]:
		if name.contains(k):
			return true
	return false


## Поля (жёлтое поле, подсолнухи): без тени, но видны и издалека — поле не обрывается кусками на границе дальности
static func field(name: String) -> bool:
	return name.begins_with(PREFIX) and (name.contains("Sunflower") or name.contains("CropField") or name.contains("Rapeseed"))


## Богатая мелочь лугов — только на «Средней» и «Высокой» (Gfx.apply прячет её на «Низкой» и «Очень низкой»)
static func rich(name: String) -> bool:
	if name.contains("Lillies") or name.contains("Rock_Small"):
		return false                              # кувшинки (одна карточка) и камешки лёгкие — на всех уровнях
	return small(name) or field(name) or name.contains("Stonewall") or name.contains("StoneWall") or name.contains("StonePile") or name.contains("Rock_Pile")


static func _tex_path(n: String) -> String:
	if n == "":
		return ""
	if _tex.has(n):
		return _tex[n]
	for k in _tex.keys():
		if String(k).to_lower() == n.to_lower():
			return _tex[k]
	return ""


static func _t(n: String) -> Texture2D:
	var p := _tex_path(n)
	return Gfx.tex(p) if p != "" else null


## Материал поверхности по записи списка ({slot, Albedo | _Leaf_Texture, _Trunk_Texture | _Triplanar_…})
static func material(e: Dictionary, remap := {}) -> Material:
	var key := str(e) + "|" + str(remap)
	if _mats.has(key):
		return _mats[key]
	var slot: String = e.get("slot", "")
	var m: Material
	if e.has("_Triplanar_Texture_Side"):
		var rm := ShaderMaterial.new()
		rm.shader = preload("res://shaders/meadow_rock.gdshader")
		rm.set_shader_parameter("side_tex", _t(e.get("_Triplanar_Texture_Side", "RockWall_Texture_01")))
		rm.set_shader_parameter("top_tex", _t(e.get("_Triplanar_Texture_Top", "Grass_Texture_01")))
		m = rm
	elif e.has("_Leaf_Texture"):
		var lt: String = e["_Leaf_Texture"]
		var tt: String = e.get("_Trunk_Texture", lt)
		var fm := ShaderMaterial.new()
		fm.shader = preload("res://shaders/meadow_foliage.gdshader")
		var grassy := slot.begins_with("Grass") or slot.begins_with("Ground_Cover") or slot.begins_with("Flowers") or slot.begins_with("WildFlowers") \
				or slot.begins_with("CropField") or slot.begins_with("Branches")
		var atlas_leaf := lt.begins_with("PolygonNatureBiomes")
		fm.set_shader_parameter("albedo_tex", _t(tt))           # «Очень низкая» подменяет большие картинки по этому имени
		fm.set_shader_parameter("leaf_tex", _t(lt))
		fm.set_shader_parameter("leaf_only", tt == lt and not atlas_leaf)
		fm.set_shader_parameter("leaf_cut", not atlas_leaf)
		var tint: Color = remap.get("tint", GRASS_TINT if grassy and not slot.begins_with("Branches") else LEAF_TINT)
		fm.set_shader_parameter("tint", tint)
		if LEAF_AVG.has(lt):
			var avg: Vector3 = LEAF_AVG[lt]
			var tg: Vector3 = BRANCH_TARGET if lt.begins_with("Branches") else LEAF_TARGET
			fm.set_shader_parameter("leaf_gain", Vector3(tg.x / avg.x, tg.y / avg.y, tg.z / avg.z))
		if grassy and not slot.begins_with("Branches") and not slot.begins_with("CropField"):
			fm.set_shader_parameter("fade", Vector2(Parts.FADE_FROM, Parts.FADE_TO))
		fm.set_shader_parameter("trunk_tint", TRUNK_TINT if not tt.begins_with("Birch") else Color(0.95, 0.94, 0.92))
		fm.set_shader_parameter("up_normal", 0.7 if grassy else 0.6)
		fm.set_shader_parameter("sway", 0.05 if grassy else 0.035)
		fm.set_shader_parameter("season", Synty.season_now)
		fm.set_shader_parameter("evergreen", grassy)
		fm.set_shader_parameter("bloom_ok", remap.has("bloom"))
		Synty.season_mats.append(fm)
		m = fm
	else:
		var sm := StandardMaterial3D.new()
		sm.roughness = 0.85
		var alb: String = e.get("Albedo", "PolygonNatureBiomes_Meadow_Texture_01")
		sm.albedo_texture = _t(alb)
		if alb.begins_with("LillyPads"):
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			sm.alpha_scissor_threshold = 0.4
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		if remap.has("tint"):
			sm.albedo_color = remap["tint"]
		sm.set_meta("alb", alb)
		m = sm
	_mats[key] = m
	Synty._mats["meadow|" + key] = m             # «Очень низкая» подменяет картинки 4096² и у них (Gfx.small_textures)
	return m


## Узел с моделью; материалы по списку набора, ступень детализации — LOD (или «@n» в имени)
static func make(name: String, remap := {}) -> Node3D:
	_index()
	var base := _base(name)
	if not on or not _paths.has(base):
		push_warning("Meadow: нет модели " + name)
		return Node3D.new()
	if not _scenes.has(base):
		_scenes[base] = load(_paths[base])
	var n := (_scenes[base] as PackedScene).instantiate() as Node3D
	var want := _lod_of(name)
	# ступени детализации по семействам («…_LOD2», «…_Branches_LOD1»): у каждого — ближайшая к want, не карточка
	var lv := {}                                      # семейство → ступени, какие есть (без карточек)
	var re := RegEx.create_from_string("^(.*)_LOD([0-9])$")
	var mis: Array = n.find_children("*", "MeshInstance3D", true, false)
	for mi: MeshInstance3D in mis:
		var m := re.search(String(mi.name))
		if m == null:
			continue
		var list: Array = _mesh_slots.get(String(mi.name), [])
		if not list.is_empty() and String((list[0] as Dictionary).get("slot", "")).begins_with("Card_"):
			continue                                  # дальняя карточка (плоская картинка дерева) — не берём
		if not lv.has(m.get_string(1)):
			lv[m.get_string(1)] = []
		lv[m.get_string(1)].append(int(m.get_string(2)))
	var fam := {}                                     # семейство → выбранная ступень: самая грубая не грубее want
	for f in lv:
		var best := -1
		var lo := 99
		for l: int in lv[f]:
			lo = mini(lo, l)
			if l <= want and l > best:
				best = l
		fam[f] = best if best >= 0 else lo
	for mi: MeshInstance3D in mis:
		var m := re.search(String(mi.name))
		if m != null and (not fam.has(m.get_string(1)) or int(fam[m.get_string(1)]) != int(m.get_string(2))):
			mi.get_parent().remove_child(mi)
			mi.free()
			continue
		var list: Array = _mesh_slots.get(String(mi.name), [])
		var spin := (base.begins_with("SM_Bld_Windmill") and String(mi.name).contains("Blades")) or String(mi.name) == "SM_Prop_WaterWheel_01_01"
		for i in mi.mesh.get_surface_count():
			var e: Dictionary = list[i] if i < list.size() else (list[0] if not list.is_empty() else {})
			mi.set_surface_override_material(i, _spin(mi.mesh, 0.45 if base.begins_with("SM_Bld") else -0.7) if spin else material(e, remap))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small(name) or field(name) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return n


## Вращающийся материал (крылья мельницы, водяное колесо): ось — самая тонкая сторона рамки сетки, через её середину
static func _spin(mesh: Mesh, speed: float) -> Material:
	var key := "spin|%d" % mesh.get_instance_id()
	if _mats.has(key):
		return _mats[key]
	var bb := mesh.get_aabb()
	var ax := Vector3(1, 0, 0)
	if bb.size.y < bb.size.x and bb.size.y <= bb.size.z:
		ax = Vector3(0, 1, 0)
	elif bb.size.z < bb.size.x and bb.size.z < bb.size.y:
		ax = Vector3(0, 0, 1)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/meadow_spin.gdshader")
	m.set_shader_parameter("albedo_tex", _t("PolygonNatureBiomes_Meadow_Texture_01"))
	m.set_shader_parameter("center", bb.get_center())
	m.set_shader_parameter("axis", ax)
	m.set_shader_parameter("speed", speed)
	_mats[key] = m
	Synty._mats["meadow|" + key] = m
	return m
