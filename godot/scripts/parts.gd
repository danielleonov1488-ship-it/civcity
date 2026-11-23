class_name Parts
extends Node3D

const Perf14 = preload("res://scripts/perf14_timers.gd")
## Пул деталей: все одинаковые детали Synty (одной раскраски) по всему городу рисуются одним MultiMesh.
## place(чертёж, где) возвращает ручку; remove(ручка) убирает детали этой постройки.
## Свободные места переиспользуются, буфер растёт удвоением.

var groups := {}          # ключ → {subs: [{mm, mmi, local}], free: [], used: int, cap: int}
var alias := {}           # прежний ключ (с цветом оттенка) → группа без оттенка: подсветка (cover.gd) ищет по нему
static var _special := {}
var _initial_draw: Array[MultiMeshInstance3D] = []
const WHEAT_BATCH := 24.0

## Оттенок — у экземпляра (12.11, владелец: «минимум 120 кадров»): одинаковые детали разных цветов (штукатурка
## каждого дома своего цвета, ставни, черепица) — один MultiMesh, цвет — в цвете экземпляра; у подкрашиваемых
## поверхностей материал белый и умножается на него (как albedo_color: то же sRGB → линейный). Видов деталей
## в городе владельца ~в 3,5 раза меньше (1955 → 531) — во столько же меньше вызовов отрисовки. Только у главного
## пула (у подсветки cover.gd — нет)
var tint_split := false
const Detail = preload("res://scripts/parts_detail.gd")
static var detail_config: Detail
var detail: Detail
var foliage_lod := false
var share_perf_meshes := true
var _shared_meshes := {}
const FOLIAGE_LOD_BIAS := 0.65
static var profile_place := false
var place_usec := 0
var max_place_usec := 0
var max_place_frame_usec := 0
var _place_frame := -1
var _place_frame_usec := 0

static var split_on := true                # для сравнений «было/стало» (test_perf split=0)
var _col := Color.WHITE                     # цвет экземпляра для последней группы из _group
static var _tint_mats := {}


## [оттенок, какие картинки подкрашены («*» — все), remap без оттенка] или [] — группа как прежде
static func _split(name: String, remap: Dictionary) -> Array:
	if name.begins_with("#") or name.begins_with("K:") or name.begins_with("M:") or remap.has("leaf"):
		return []
	var has_t := remap.has("tint")
	var tints: Dictionary = remap.get("tints", {})
	if has_t == (not tints.is_empty()):
		return []                              # без оттенка — как прежде; оба сразу — тоже (редкость)
	var col: Color
	var mark := "*"
	if has_t:
		col = remap["tint"]
	else:
		var keys := tints.keys()
		col = tints[keys[0]]
		for k in keys:
			if tints[k] != col:
				return []                      # разным картинкам разные цвета — один цвет экземпляра их не передаст
		keys.sort()
		mark = ",".join(keys)
	var base := remap.duplicate()
	base.erase("tint")
	base.erase("tints")
	return [col, mark, base]


func _group(name: String, remap: Dictionary, tile := Vector2i(-1, -1)) -> Dictionary:
	var ts := "" if tile.x < 0 else "|%d,%d" % [tile.x, tile.y]
	var key := name + "|" + str(remap) + ts
	_col = Color.WHITE
	if groups.has(key):
		return groups[key]
	if alias.has(key):
		_col = _split(name, remap)[0]
		return alias[key]
	var sp := _split(name, remap) if tint_split else []
	if not sp.is_empty():
		var tkey := name + "|" + str(sp[2]) + "|tint:" + str(sp[1]) + ts
		var tg: Dictionary = groups.get(tkey, {})
		if tg.is_empty() and not groups.has(tkey + "|no"):
			tg = _tint_group(name, sp, tkey, tile)
			if tg.is_empty():
				groups[tkey + "|no"] = {"subs": [], "free": [], "used": 0, "cap": 0, "key": tkey + "|no"}
		if not tg.is_empty():
			alias[key] = tg
			_col = sp[0]
			return tg
	var g := {"subs": [], "free": [], "used": 0, "cap": 0, "key": key}
	if name.begins_with("#"):
		var ssub := _sub(_special_mesh(name), Transform3D.IDENTITY)
		_small(name, ssub, tile)
		if name.begins_with("#room") or name.begins_with("#plate"):
			(ssub["mmi"] as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # нутро тени не бросает
		g["subs"].append(ssub)
	else:
		var src := Synty.make(name, remap)
		for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
			var copy_started := Perf14.begin()
			var mesh := _group_mesh(mi, tile, name)
			Perf14.end(Perf14.MESH_COPY, copy_started)
			var sub := _sub(mesh, Citizen._rel(mi, src))
			_small(name, sub, tile)
			_set_foliage_lod(sub, tile, name)
			g["subs"].append(sub)
			if detail != null and tile.x < 0:
				detail.add_shadow(self, g, sub, name, mi.mesh)
		src.free()
	groups[key] = g
	return g


static func is_foliage(name: String) -> bool:
	var model := name.trim_prefix("M:").trim_prefix("SM_Env_")
	if model == name.trim_prefix("M:"):
		return false
	for prefix: String in ["Tree", "Bush", "Grass", "Flowers", "Wildflowers",
			"Garden_Plants", "Ground_Cover", "Lillies", "Sunflower", "CropField", "Rapeseed"]:
		if model.begins_with(prefix):
			return true
	return false


func _lod_mesh(source: Mesh, tile: Vector2i, name: String) -> Mesh:
	if foliage_lod and tile.x >= 0 and is_foliage(name):
		return Detail.with_missing_lods(source)
	return detail.lod_mesh(source, tile, name) if detail != null else source


func _group_mesh(mi: MeshInstance3D, tile: Vector2i, name: String) -> Mesh:
	var source := _lod_mesh(mi.mesh, tile, name)
	var overrides: Array[Material] = []
	for s in source.get_surface_count():
		overrides.append(mi.get_surface_override_material(s))
	return mesh_with_materials(_shared_meshes, source, overrides,
		tile.x >= 0 and _fading_detail(name), share_perf_meshes)


static func mesh_with_materials(cache: Dictionary, source: Mesh, overrides: Array[Material], faded: bool, share: bool) -> Mesh:
	var key := PackedInt64Array()
	if share:
		key.append(source.get_instance_id())
		key.append(int(faded))
		var copy_needed := faded
		for s in overrides.size():
			var m := overrides[s]
			key.append(m.get_instance_id() if m != null else 0)
			copy_needed = copy_needed or (m != null and m != source.surface_get_material(s))
		if not copy_needed:
			return source
		if cache.has(key):
			return cache[key]
	var mesh := source.duplicate() as Mesh
	for s in overrides.size():
		if overrides[s] != null:
			mesh.surface_set_material(s, overrides[s])
	if share:
		if faded:
			_far_fade(mesh)
			mesh.set_meta("parts_faded", true)
		cache[key] = mesh
	return mesh


static func _fading_detail(name: String) -> bool:
	return name.contains("Grass") or name.contains("Flowers") or name.contains("Lillies") \
		or name.contains("Pebbles") or name.contains("Garden_Plants") or Meadow.small(name)


func _set_foliage_lod(sub: Dictionary, tile: Vector2i, name: String) -> void:
	if foliage_lod and tile.x >= 0 and is_foliage(name):
		sub["foliage_lod"] = true
		(sub["mmi"] as MultiMeshInstance3D).lod_bias = FOLIAGE_LOD_BIAS


## Группа без оттенка: модель с remap без цвета, у подкрашиваемых поверхностей — белый материал «умножить на цвет
## экземпляра». Модель с цветом в вершинах (умножился бы и он) или не StandardMaterial3D — {} (группа на каждый цвет)
func _tint_group(name: String, sp: Array, tkey: String, tile: Vector2i) -> Dictionary:
	var marks := {}
	for k in str(sp[1]).split(","):
		marks[k] = true
	var src := Synty.make(name, sp[2])
	var subs := []
	var ok := true
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		var source := _lod_mesh(mi.mesh, tile, name)
		var overrides: Array[Material] = []
		for s in source.get_surface_count():
			var m := mi.get_surface_override_material(s)
			if m != null:
				var hit: bool = sp[1] == "*" or (m.has_meta("alb") and marks.has(str(m.get_meta("alb"))))
				if hit:
					if not m is StandardMaterial3D or (source is ArrayMesh and (source as ArrayMesh).surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR):
						ok = false
						break
					# «tint» меняет прозрачность, «tints» — нет.
					var a: float = (sp[0] as Color).a if sp[1] == "*" else (m as StandardMaterial3D).albedo_color.a
					m = _tint_mat(m as StandardMaterial3D, a)
			overrides.append(m)
		if not ok:
			break
		var mesh := mesh_with_materials(_shared_meshes, source, overrides,
			tile.x >= 0 and _fading_detail(name), share_perf_meshes)
		subs.append([mesh, Citizen._rel(mi, src), mi.mesh])
	src.free()
	if not ok:
		return {}
	var g := {"subs": [], "free": [], "used": 0, "cap": 0, "key": tkey, "tint": true}
	for e: Array in subs:
		var sub := _sub(e[0], e[1], true)
		_small(name, sub, tile)
		_set_foliage_lod(sub, tile, name)
		g["subs"].append(sub)
		if detail != null and tile.x < 0:
			detail.add_shadow(self, g, sub, name, e[2])
	groups[tkey] = g
	return g


## Белая копия материала, умножаемая на цвет экземпляра (одна на все цвета)
static func _tint_mat(m: StandardMaterial3D, a: float) -> StandardMaterial3D:
	var k := "%d|%.4f" % [m.get_instance_id(), a]
	if _tint_mats.has(k):
		return _tint_mats[k]
	var t := m.duplicate() as StandardMaterial3D
	t.albedo_color = Color(1, 1, 1, a)
	t.vertex_color_use_as_albedo = true
	t.vertex_color_is_srgb = true
	_tint_mats[k] = t
	Synty._mats["tint|" + k] = t                # «Очень низкая» подменяет картинки и у них (Gfx.small_textures)
	return t


## мелочь (трава, цветы, кувшинки, камешки) — без тени и только вблизи: так быстрее. 12.11: и любая деталь меньше
## SMALL_SHADOW по самой длинной стороне (горшки, кувшины, мешки, корзины, таблички) — без тени: на картинке разница
## в среднем 0,1 из 255, теней на 20% меньше вызовов (город владельца: 2828 → 2248), +5–7% кадров
const SMALL_SHADOW := 0.9
static func _small(name: String, sub: Dictionary, tile: Vector2i) -> void:
	if name == CatCivic.WHEAT or name == CatCivic.WHEAT_DENSE:
		var batch: MultiMeshInstance3D = sub["mmi"]
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if tile.x >= 0:
			# Шейдер уже погасил все пучки к этой дальности. Границы не меняются при сносе.
			var corner := Vector3(tile.x * WHEAT_BATCH - 1.0, -16, tile.y * WHEAT_BATCH - 1.0)
			batch.custom_aabb = AABB(corner, Vector3(WHEAT_BATCH + 2.0, 42, WHEAT_BATCH + 2.0))
			batch.visibility_range_end = 94.0 if name == CatCivic.WHEAT_DENSE else 174.0
		return
	if name.begins_with("#field_cover_"):
		(sub["mmi"] as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return
	var mesh: Mesh = (sub["mm"] as MultiMesh).mesh
	if mesh != null:
		var sz := mesh.get_aabb().size
		if maxf(sz.x, maxf(sz.y, sz.z)) < SMALL_SHADOW:
			(sub["mmi"] as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _fading_detail(name):
		var mmi: MultiMeshInstance3D = sub["mmi"]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if tile.x >= 0:
			mmi.visibility_range_end_margin = 20.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			_small_mmis.append(mmi)
			_apply_range(mmi)
			if not mesh.has_meta("parts_faded"):
				_far_fade(mesh)
	elif Meadow.field(name):
		(sub["mmi"] as MultiMeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # поля набора Meadow — без тени


## 13.11: мелочь природы гаснет с расстоянием сама (каждая травинка — по своему расстоянию), а не кусками 48 м разом
## на границе visibility_range: иначе на лугах видны прямоугольники «с травой / без травы». Материалы Synty — копия
## с растворением по точкам (дизеринг) от FADE_FROM до FADE_TO м; листва набора Meadow — свой шейдер (параметр fade)
## (дальность куска — 150 м до его середины; куски 48 м — до края ~34 м: к FADE_TO + 34 травинки уже погасли сами,
## кусок не обрезает видимую траву прямоугольником)
const FADE_FROM := 85.0
const FADE_TO := 115.0
static var _fade_mats := {}
## Настройка «Трава и цветы» (15.11): во сколько раз дальше (или ближе) прежнего видна мелочь природы; off — спрятана
## совсем. 1.0 — как было (дальность куска 150 м, травинки гаснут с 85 до 115 м); от 3.0 — куски не отсекаются по дальности
static var grass_k := 1.0
static var grass_off := false
static var _small_mmis: Array = []


static func _apply_range(mmi: MultiMeshInstance3D) -> void:
	if grass_off:
		mmi.visibility_range_end = 0.5
	elif grass_k >= 3.0:
		mmi.visibility_range_end = 0.0
	else:
		mmi.visibility_range_end = 150.0 * grass_k


## Дальность мелочи поменяли в настройках: куски, травинки и «Очень низкая» (картинки) — все сразу
static func set_grass_range(k: float, off: bool) -> void:
	grass_k = k
	grass_off = off
	var keep: Array = []
	for m in _small_mmis:
		if is_instance_valid(m):
			_apply_range(m)
			keep.append(m)
	_small_mmis = keep
	var fv := Vector2(FADE_FROM, FADE_TO) * k
	for m in Meadow._mats.values():
		if m is ShaderMaterial and (m as ShaderMaterial).get_shader_parameter("fade") is Vector2 and (m as ShaderMaterial).get_shader_parameter("fade") != Vector2.ZERO:
			(m as ShaderMaterial).set_shader_parameter("fade", fv)
	for m in _fade_mats.values():
		(m as BaseMaterial3D).distance_fade_max_distance = FADE_FROM * k
		(m as BaseMaterial3D).distance_fade_min_distance = FADE_TO * k

static func _far_fade(mesh: Mesh) -> void:
	if mesh == null:
		return
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		if m is ShaderMaterial:
			if (m as ShaderMaterial).get_shader_parameter("fade") != null:
				(m as ShaderMaterial).set_shader_parameter("fade", Vector2(FADE_FROM, FADE_TO) * grass_k)
			continue
		if not m is BaseMaterial3D:
			continue
		var k := m.get_instance_id()
		if not _fade_mats.has(k):
			var f := m.duplicate() as BaseMaterial3D
			f.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			f.distance_fade_max_distance = FADE_FROM * grass_k          # больше min — растворяется вдаль: видно до FADE_FROM, нет к FADE_TO
			f.distance_fade_min_distance = FADE_TO * grass_k
			_fade_mats[k] = f
			Synty._mats["fade|%d" % k] = f              # «Очень низкая» подменяет картинки и у неё (Gfx.small_textures)
		mesh.surface_set_material(s, _fade_mats[k])


func _sub(mesh: Mesh, local: Transform3D, colors := false) -> Dictionary:
	var started := Perf14.begin()
	var value := _sub_profiled(mesh, local, colors)
	Perf14.end(Perf14.MULTIMESH, started)
	return value


func _sub_profiled(mesh: Mesh, local: Transform3D, colors := false) -> Dictionary:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return {"mm": mm, "mmi": mmi, "local": local}


## Отмечаем только детали, которые рисуются при выбранном качестве.
func hide_initial_batches() -> void:
	for child: Node in get_children():
		if child is MultiMeshInstance3D and (child as MultiMeshInstance3D).visible:
			var mmi := child as MultiMeshInstance3D
			mmi.hide()
			_initial_draw.append(mmi)
	show()


## После первого кадра камеры добавляем детали города и природу порциями.
func show_initial_batches() -> void:
	var tree := get_tree()
	for start in range(0, _initial_draw.size(), 96):
		var started := Perf14.begin()
		for mmi: MultiMeshInstance3D in _initial_draw.slice(start, start + 96):
			if is_instance_valid(mmi):
				mmi.show()
		Perf14.detail("load_city_draw_batch", started)
		await tree.process_frame
	_initial_draw.clear()


static func _special_mesh(name: String) -> Mesh:
	if _special.has(name):
		return _special[name]
	if name == CatCivic.WHEAT or name == CatCivic.WHEAT_DENSE:
		_special[name] = CatCivic.wheat_mesh(name == CatCivic.WHEAT_DENSE)
		return _special[name]
	if name.begins_with("#field_cover_"):
		_special[name] = CatCivic.field_cover_mesh(name.trim_prefix("#field_cover_"))
		return _special[name]
	if name.begins_with("#mil_"):                  # палатки, мишени, баллисты… Легиона (cat_military.gd)
		_special[name] = CatMilitary.kit_mesh(name)
		return _special[name]
	if name.begins_with("#d2_"):                   # золотой орёл, обелиск… украшений этапа 5 (cat_decor2.gd)
		_special[name] = CatDecor2.kit_mesh(name)
		return _special[name]
	if name.begins_with("#kerb"):                  # камни бордюра у домуса и храма (kerb.gd)
		_special[name] = Kerb.mesh(name)
		return _special[name]
	if name.begins_with("#sign:") or name.begins_with("#bsign:") or name.begins_with("#bricks_") or name.begins_with("#quoin_") \
			or name.begins_with("#dress:"):
		# вывески (над дверью и на кронштейне), кирпич под отбитой штукатуркой, угловые камни домов Synty, детали
		# наполнения «#dress:» — кронштейн для горшка, лёгкий ящик цветов… (CatDress)
		_special[name] = CatDress.kit_mesh(name)
		return _special[name]
	if name.begins_with("#room") or name.begins_with("#plate"):    # нутро построек и перекрытия (interiors.gd)
		_special[name] = Interiors.mesh(name)
		return _special[name]
	if name.begins_with("#hp_"):                   # товар у лавки — те же вещицы, что в руках у жителей (HandProps)
		_special[name] = HandProps._kit("#" + name.substr(4))
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
		"#marble", "#bench":
			# #bench — каменная скамья трибуны (как мрамор; по ней рассаживает зрителей Spectacle)
			m = Synty.material("Marble_01").duplicate()
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(0.4, 0.4, 0.4)
		"#water":
			# вода бассейнов и фонтанов — живая (рябь, блики, прожилки света: shaders/pool_water.gdshader)
			var wm := ShaderMaterial.new()
			wm.shader = load("res://shaders/pool_water.gdshader")
			bm.material = wm
			_special[name] = bm
			return bm
		"#duck", "#duck_f", "#swan":
			# утка, уточка, лебедь — бесплатные модели в духе Synty (fauna.gd); нет файла — прежние из Kit
			var am: Mesh = Fauna.bird_mesh(name.substr(1))
			if am == null:
				am = _bird_mesh(name == "#swan")
			_special[name] = am
			return am
		"#lamp_post", "#wall_lamp", "#wall_lamp_dim":
			# #wall_lamp_dim — фонарик у двери жилого дома: ночью еле теплится (улицу светят фонари-украшения)
			var lm := _lamp_mesh(name != "#lamp_post", name == "#wall_lamp_dim")
			_special[name] = lm
			return lm
		"#shutters_green", "#shutters_brown", "#shutters_blue", "#window_box", "#chimney", "#laundry":
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
		"#laundry":
			# бельё на балконе (CatDecor._balcony): два столбика по углам, верёвка, на ней туники и простыня — сохнут
			for sx: float in [-1.08, 1.08]:
				k.boxc(Vector3(sx, 0.78, 1.02), Vector3(0.06, 1.56, 0.06), Color("7a4e2c"), [])
			k.rod(Vector3(-1.08, 1.5, 1.02), Vector3(1.08, 1.5, 1.02), 0.012, 4, Color("d8ccb0"))
			var cloth := [[-0.75, 0.42, 0.5, Color("e8e2d6")], [-0.22, 0.34, 0.42, Color("b4432f")], [0.22, 0.3, 0.36, Color("4d7397")],
				[0.68, 0.48, 0.56, Color("f4ead6")]]
			for c: Array in cloth:
				var w: float = c[1]
				var h: float = c[2]
				k.boxc(Vector3(float(c[0]), 1.5 - h / 2.0, 1.02), Vector3(w, h, 0.025), c[3], [])
				# прищепки
				for px: float in [-w / 2.0 + 0.04, w / 2.0 - 0.04]:
					k.boxc(Vector3(float(c[0]) + px, 1.51, 1.02), Vector3(0.025, 0.05, 0.04), Color("8a5a3c"), [])
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
	var started := Perf14.begin()
	var cap: int = maxi(16, int(g["cap"]) * 2)
	for sub in g["subs"]:
		var mm: MultiMesh = sub["mm"]
		var buffer := mm.buffer
		mm.instance_count = cap
		# В оконном рендере сохраняем старые экземпляры и добавляем пустые места.
		if DisplayServer.get_name() != "headless":
			var stride := 12 + 4 * int(mm.use_colors) + 4 * int(mm.use_custom_data)
			buffer.resize(cap * stride)
			mm.buffer = buffer
	g["cap"] = cap
	Perf14.end(Perf14.BUFFER, started)


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


static func _batch_tile(name: String, pos: Vector3) -> Vector2i:
	if name == CatCivic.WHEAT or name == CatCivic.WHEAT_DENSE:
		return Vector2i(Vector2(pos.x, pos.z) / WHEAT_BATCH)
	return Vector2i(-1, -1)


## Пока здание растёт, готовим те же группы, которые возьмёт готовая модель.
func prepare_groups(bp: Bp, xf: Transform3D, subst: Dictionary, alive: Callable) -> void:
	var tree := get_tree()
	var deadline := Time.get_ticks_usec() + 3000
	var started := Perf14.begin()
	for p: Array in bp.parts:
		if Time.get_ticks_usec() >= deadline:
			Perf14.detail("placement_parts_prepare", started)
			await tree.process_frame
			if not alive.call():
				return
			started = Perf14.begin()
			deadline = Time.get_ticks_usec() + 3000
		var name: String = subst.get(p[0], p[0])
		var local: Transform3D = p[1]
		_group(name, p[2], _batch_tile(name, xf * local.origin))
	Perf14.detail("placement_parts_prepare", started)


## Поставить чертёж; xf — где стоит постройка. Возвращает ручку [[группа, место], …]
func place(bp: Bp, xf: Transform3D, subst := {}) -> Array:
	var handles := []
	var started := Time.get_ticks_usec() if profile_place else 0
	for p in bp.parts:
		var name: String = subst.get(p[0], p[0])
		var t: Transform3D = xf * (p[1] as Transform3D)
		var tile := _batch_tile(name, t.origin)
		handles.append(_place_part(name, t, p[2], tile))
	if started > 0:
		var usec := Time.get_ticks_usec() - started
		place_usec += usec
		max_place_usec = maxi(max_place_usec, usec)
		var frame := Engine.get_process_frames()
		if frame != _place_frame:
			_place_frame = frame
			_place_frame_usec = 0
		_place_frame_usec += usec
		max_place_frame_usec = maxi(max_place_frame_usec, _place_frame_usec)
	return handles


func _place_part(name: String, xf: Transform3D, remap: Dictionary, tile: Vector2i) -> Array:
	var group_started := Perf14.begin()
	var g := _group(name, remap, tile)
	Perf14.end(Perf14.PARTS, group_started)
	if detail != null and tile.x < 0 and detail.uses_area(name, g["key"]):
		g = detail.area_group(self, groups, g, xf.origin)
	var slot := _alloc(g)
	var tinted := g.has("tint")
	var area := g.has("area")
	var use_range := area and detail.tiny and Detail.prop(name)
	for sub: Dictionary in g["subs"]:
		var mm: MultiMesh = sub["mm"]
		var pose := xf * (sub["local"] as Transform3D)
		mm.set_instance_transform(slot, pose)
		if tinted and mm.use_colors:
			mm.set_instance_color(slot, _col)
		if area or sub.has("casts"):
			detail.bounds(sub, pose, area, use_range)
	return [g, slot]


## Одна деталь; tiled — природа: кусками по 48 м, чтобы невидимые куски не рисовались
func place_one(name: String, xf: Transform3D, remap := {}, tiled := false) -> Array:
	var tile := Vector2i(int(xf.origin.x / 48.0), int(xf.origin.z / 48.0)) if tiled else Vector2i(-1, -1)
	return [_place_part(name, xf, remap, tile)]


## Спрятать детали на время (ролик: дерево заслонило героя): возвращает [[MultiMesh, место, преобразование], …] для restore
func hide_handles(handles: Array) -> Array:
	var saved := []
	var zero := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -100, 0))
	for h in handles:
		var g: Dictionary = h[0]
		var slot: int = h[1]
		for sub in g["subs"]:
			var mm: MultiMesh = sub["mm"]
			if slot < mm.instance_count:
				saved.append([mm, slot, mm.get_instance_transform(slot)])
				mm.set_instance_transform(slot, zero)
	return saved


## Деталь ручки h ([группа, место]) сейчас спрятана (нулевой масштаб)
func is_hidden(h: Array) -> bool:
	var sub: Dictionary = (h[0] as Dictionary)["subs"][0]
	var mm: MultiMesh = sub["mm"]
	return int(h[1]) >= mm.instance_count or mm.get_instance_transform(int(h[1])).basis.get_scale().length() < 1e-6


## Вернуть спрятанное hide_handles (место, которое за это время заняли другим, не трогаем)
func restore(saved: Array) -> void:
	for e: Array in saved:
		var mm: MultiMesh = e[0]
		var slot: int = e[1]
		if slot < mm.instance_count and mm.get_instance_transform(slot).basis.get_scale().length() < 1e-6:
			mm.set_instance_transform(slot, e[2])


func remove(handles: Array) -> void:
	var zero := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -100, 0))
	for h in handles:
		var g: Dictionary = h[0]
		var slot: int = h[1]
		for sub in g["subs"]:
			(sub["mm"] as MultiMesh).set_instance_transform(slot, zero)
		var free: Array = g["free"]
		free.append(slot)
		if g.has("area") and free.size() == int(g["used"]):
			free.clear()
			g["used"] = 0
			for sub: Dictionary in g["subs"]:
				(sub["mm"] as MultiMesh).visible_instance_count = 0
				(sub["mmi"] as MultiMeshInstance3D).custom_aabb = AABB()
				sub.erase("diameter")


## Спрятать (нулевой масштаб) или вернуть детали ручки на место xf — деревья под призраком постройки (game.gd, 3.7)
func set_hidden(handles: Array, hidden: bool, xf := Transform3D.IDENTITY) -> void:
	var zero := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -100, 0))
	for h in handles:
		var g: Dictionary = h[0]
		var slot: int = h[1]
		for sub in g["subs"]:
			(sub["mm"] as MultiMesh).set_instance_transform(slot, zero if hidden else xf * (sub["local"] as Transform3D))


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
	fill_ghost(root, bp, mode, col)
	return root


static func fill_ghost(root: Node3D, bp: Bp, mode: String, col: Color, tree: SceneTree = null) -> void:
	var wheat := {CatCivic.WHEAT: [], CatCivic.WHEAT_DENSE: []}
	var mat: Material
	match mode:
		"shell": mat = tint_material(col, 0.03)
		"outline": mat = outline_material(col)
		"thumbnail": pass
		_: mat = tint_material(col, 0.005)
	root.set_meta("mat", mat)
	var deadline := Time.get_ticks_usec() + 2500
	for p: Array in bp.parts:
		if tree != null and Time.get_ticks_usec() >= deadline:
			await tree.process_frame
			if not is_instance_valid(root) or root.is_queued_for_deletion():
				return
			deadline = Time.get_ticks_usec() + 2500
		var name: String = p[0]
		if wheat.has(name):
			(wheat[name] as Array).append(p[1])
			continue
		var n: Node3D
		if name.begins_with("#"):
			var mi := MeshInstance3D.new()
			mi.mesh = _special_mesh(name)
			n = mi
		else:
			n = Synty.make(p[0], p[2])
		n.transform = p[1]
		root.add_child(n)
		_ghost_material(n, mode, mat)
	# Призрак поля и короткая анимация стройки тоже рисуют пучки пачками.
	for name: String in wheat:
		var transforms: Array = wheat[name]
		if transforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _special_mesh(name)
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		root.add_child(mmi)
		_ghost_material(mmi, mode, mat)


static func _ghost_material(node: Node3D, mode: String, mat: Material) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mode == "place":
			geometry.material_overlay = mat
		else:
			geometry.material_override = mat
	for child: Node3D in node.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mode == "place":
			geometry.material_overlay = mat
		else:
			geometry.material_override = mat


static func ghost_color(g: Node3D, col: Color) -> void:
	var m: ShaderMaterial = g.get_meta("mat")
	if m and m.shader == _tint_shader:
		m.set_shader_parameter("tint", col)
