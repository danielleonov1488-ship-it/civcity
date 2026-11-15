class_name CatNature
extends RefCounted
## Раздел «Природа» в украшениях (15.11, владелец: «деревья и цветы нового пака — в меню украшений»): инструменты
## «Дерево», «Куст», «Пальма», «Цветы» — каждый щелчок ставит случайную модель из ВСЕХ наших наборов (Meadow Forest и
## Ancient Empire); отдельные модели Meadow — камни, груды камней, каменная стенка, подсолнухи, кувшинки.
## Это обычные украшения (Defs.B, sub «nature»): переносятся, сносятся, сохраняются (variant = номер модели в списке,
## color у цветов — номер цвета), картинки карточек рисуются тем же конвейером. Размеры — в метрах мира (чертёж потом
## уменьшается до «кукольного» масштаба Catalog.DECOR, поэтому делим на него).

## Списки: [модель, высота в мире, м] — высота подгоняет масштаб под габариты настоящей модели
const TREES := [
	["M:SM_Env_Tree_Birch_01", 5.6], ["M:SM_Env_Tree_Birch_02", 5.2], ["M:SM_Env_Tree_Birch_03", 3.6],
	["M:SM_Env_Tree_Meadow_01", 5.8], ["M:SM_Env_Tree_Meadow_02", 4.6],
	["M:SM_Env_Tree_Fruit_01", 4.2], ["M:SM_Env_Tree_Fruit_02", 3.9], ["M:SM_Env_Tree_Fruit_03", 3.3],
	["SM_Env_Tree_01", 4.4], ["SM_Env_Tree_02", 4.4], ["SM_Env_Tree_03", 4.2], ["SM_Env_Tree_04", 4.0],
	["SM_Env_Tree_Large_01", 5.8], ["SM_Env_Tree_Large_02", 5.8], ["SM_Env_Tree_Large_03", 5.8],
	["SM_Env_Tree_Thin_01", 5.6], ["SM_Env_Tree_Thin_02", 5.0]]
const BUSHES := [
	["M:SM_Env_Bush_01", 1.6], ["M:SM_Env_Bush_02", 1.1], ["M:SM_Env_Bush_03", 1.7],
	["SM_Env_Bush_Cluster_01", 1.0], ["SM_Env_Bush_Cluster_02", 1.0], ["SM_Env_Bush_Cluster_03", 1.0], ["SM_Env_Bush_Cluster_04", 1.0], ["SM_Env_Bush_Cluster_05", 1.0],
	["SM_Env_Tree_Bush_01", 1.5], ["SM_Env_Tree_Bush_02", 1.4], ["SM_Env_Tree_Bush_03", 1.5],
	["SM_Env_Garden_Plants_01", 0.7], ["SM_Env_Garden_Plants_02", 0.7], ["SM_Env_Garden_Plants_03", 0.7], ["SM_Env_Garden_Plants_04", 0.7],
	["SM_Env_Garden_Plants_05", 0.7], ["SM_Env_Garden_Plants_06", 0.7], ["SM_Env_Garden_Plants_07", 0.7]]
const PALMS := [["SM_Env_Tree_Palm_01", 4.6], ["SM_Env_Tree_Palm_02", 4.6], ["SM_Env_Tree_Palm_03", 4.6]]
const ROCKS := [["M:SM_Env_Rock_01", 1.0], ["M:SM_Env_Rock_02", 0.9], ["M:SM_Env_Rock_03", 1.1], ["M:SM_Env_Rock_04", 0.8], ["M:SM_Env_Rock_05", 0.9],
	["M:SM_Env_Rock_06", 0.7], ["M:SM_Env_Rock_Round_01", 0.9]]
const STONES := [["M:SM_Prop_StonePile_01", 0.8], ["M:SM_Prop_StonePile_02", 0.8], ["M:SM_Prop_StonePile_03", 0.9], ["M:SM_Prop_StoneStack_01", 1.0],
	["M:SM_Prop_StoneStack_02", 1.0], ["M:SM_Env_Rock_Pile_02", 0.9], ["M:SM_Env_Rock_Small_Pile_01", 0.5], ["M:SM_Env_Rock_Small_Pile_02", 0.5]]
const WALLS := [["M:SM_Prop_Stonewall_Long_01", 1.1], ["M:SM_Prop_StoneWall_01", 1.0], ["M:SM_Prop_StoneWall_02", 1.0],
	["M:SM_Prop_Stonewall_Small_01", 0.7], ["M:SM_Prop_Stonewall_Small_02", 0.7]]
const LILIES := ["M:SM_Env_Lillies_01", "M:SM_Env_Lillies_02", "M:SM_Env_Lillies_03"]
## Цветы: куртина — модели набора по кругу; облик 0…2 — полевые цветы (разные картинки), 3…5 — куртины набора
const FLOWER_LOOKS := 6
## Цвета цветов (номер = color у украшения; номера — как fmode в shaders/meadow_foliage.gdshader): белые, розовые, красные,
## жёлтые, сиреневые, синие, 6 — пёстрые (как в наборе)
const FLOWER_COLORS := [["Белые", Color("f5f2e8")], ["Розовые", Color("ec7fae")], ["Красные", Color("c71a1a")], ["Жёлтые", Color("ffd129")],
	["Сиреневые", Color("8445c7")], ["Синие", Color("3361e6")], ["Пёстрые", Color("f0a060")]]

## Список по виду украшения (Defs.B[...]["nat"])
static func list_of(kind: String) -> Array:
	match kind:
		"tree": return TREES
		"bush": return BUSHES
		"palm": return PALMS
		"rock": return ROCKS
		"stones": return STONES
		"wall": return WALLS
	return []


## Сколько обликов у вида (Defs.B["variants"])
static func count_of(kind: String) -> int:
	match kind:
		"flowers": return FLOWER_LOOKS
		"lilies": return LILIES.size()
		"sunflowers": return 3
	return list_of(kind).size()


## Номер цвета цветов в границах (чужие значения color — «пёстрые»)
static func flower_color(color: int) -> int:
	return color if color >= 0 and color < FLOWER_COLORS.size() else FLOWER_COLORS.size() - 1


## Модель из списка в чертёж: высота в мире h — масштаб по настоящему размеру модели
static func _add(b: Bp, name: String, h: float, pos := Vector3.ZERO, yaw := -1.0, rm := {}, wide := false) -> void:
	var box := Bp.model_aabb(name)
	var dim := box.size.y if not wide else maxf(box.size.x, box.size.z)
	var s := (h / Catalog.DECOR) / maxf(dim, 0.05)
	var y := yaw if yaw >= 0.0 else b.rng.randf() * TAU
	b.parts.append([name, b.base * Transform3D(Basis(Vector3.UP, y).scaled(Vector3.ONE * s), pos), rm.duplicate()])


static func make(b: Bp, type: String, variant: int, color: int) -> void:
	b.door = Vector3(0, 0, 1.0)
	var kind := String((Defs.B.get(type, {}) as Dictionary).get("nat", ""))
	var n := count_of(kind)
	var v := posmod(variant, maxi(n, 1))
	match kind:
		"tree", "bush", "palm", "rock", "stones":
			var e: Array = list_of(kind)[v]
			_add(b, String(e[0]), float(e[1]), Vector3.ZERO, -1.0, {}, kind == "rock" or kind == "stones")
			if kind == "tree" and b.rng.randf() < 0.5:
				_add(b, "M:SM_Env_Grass_Tall_Clump_0%d" % (1 + b.rng.randi() % 5), 0.55, Vector3(0.45, 0, 0.3))
		"wall":
			var e2: Array = WALLS[v]
			_add(b, String(e2[0]), float(e2[1]), Vector3.ZERO, 0.0, {}, true)
		"flowers":
			_flowers(b, v, flower_color(color))
		"sunflowers":
			for i in 5 + v:
				var a := b.rng.randf() * TAU
				var r := 0.25 + sqrt(b.rng.randf()) * 0.7
				_add(b, "M:SM_Env_Sunflower_01", b.rng.randf_range(1.5, 2.0), Vector3(cos(a) * r, 0, sin(a) * r))
		"lilies":
			b.parts.append([LILIES[v], b.base * Transform3D(Basis(Vector3.UP, b.rng.randf() * TAU).scaled(Vector3.ONE * 0.9), Vector3.ZERO), {}])


## Куртина цветов выбранного цвета: полевые цветы и плоские цветочки по кругу ~0,8 м, внизу пара кустиков травы
static func _flowers(b: Bp, v: int, col: int) -> void:
	var rm := {"fmode": float(col) if col < FLOWER_COLORS.size() - 1 else 100.0}
	var cnt := 7 if v < 3 else 5
	for i in cnt:
		var a := b.rng.randf() * TAU
		var r := sqrt(b.rng.randf()) * 0.85
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if v < 3:
			_add(b, "M:SM_Env_Wildflowers_0%d" % (1 + (v + i) % 3), b.rng.randf_range(0.75, 1.0), p, -1.0, rm)
		elif i < 3:
			_add(b, "M:SM_Env_Wildflowers_0%d" % (1 + (i + v) % 3), b.rng.randf_range(0.75, 1.0), p, -1.0, rm)
		else:
			_add(b, "M:SM_Env_Flowers_Flat_0%d" % (1 + b.rng.randi() % 3), 0.28, p, -1.0, rm)
	for i in 3:
		var a2 := b.rng.randf() * TAU
		_add(b, "M:SM_Env_Grass_Med_Clump_0%d" % (1 + b.rng.randi() % 3), 0.5, Vector3(cos(a2), 0, sin(a2)) * b.rng.randf_range(0.2, 0.8))
