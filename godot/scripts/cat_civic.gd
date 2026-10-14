class_name CatCivic
extends RefCounted
## Облик построек (Город: станция, склад, науки, поля, бани, театры). Чертёж Bp строится в родных размерах Synty;
## Catalog.make потом уменьшает его до «кукольного» масштаба (Catalog.ARCH).
## Люди при деле (Catalog._actors) стоят в заданных точках — постройки оставляют им место: станция (1, 0, 1) и
## стражник (−2,6, 0, 3,6); скрипторий — писец на табурете (1,2, 0, 1,7); школа — учитель (0, 0, 2,6);
## баня — служитель (−2, 0, 2,6); одеон — сцена высотой 0,5 у z = 3,4; театр — сцена высотой 0,6 у z = 5,6…5,8.
## Семьи ждут перед станцией в прямоугольнике ±3,5 × ±4,5 м вокруг входа — там ничего не ставим, кроме мелочи у стены.

const M := Bp.M
const FL := Bp.FL
const WHITE := Color(1.0, 0.97, 0.92)
## Ткань велариев и навесов — светлая охра (не ковровый узор)
const CLOTH := {"PolygonAncientEmpire_01_A": "PolygonAncientEmpire_01_C", "tints": {"PolygonAncientEmpire_01_C": Color(1.0, 0.88, 0.62)}}
## Камень наружных стен театров — тёплый травертин
const TRAVERTINE := {"tints": {"Building_Large_Brick_01": Color(1.0, 0.93, 0.8)}}
## Мраморная облицовка (арки и ниши вместо серого руста)
const MARBLE := {"Building_Large_Brick_01": "Building_Marble_01"}
## Статуя в нише стены (SM_Bld_Wall_Alcove_01) — почти в рост ниши, крупнее прохожих
const NICHE := 0.76


# =====================================================================
#   общие приёмы
# =====================================================================

## Коробка стен с заданными проёмами. fl — этажи снизу вверх: {сторона: [имена по модулям]}; "" — пропуск модуля,
## недостающие — глухая стена. o: trim (карниз), f0 (с какого этажа), sides (какие стороны), top_trim, dark,
## skin — своя раскраска (словарь от _skin или массив по этажам) вместо цвета здания, trim_skin — раскраска карнизов
## и углов (белые карнизы на цветной стене), plain — стороны без карнизов и цоколя (задний фасад — экономия деталей),
## bare — стороны совсем без карнизов, даже под крышей (задворки больших построек),
## end_from — с какого этажа ставить угловые столбики (ниже их закрывают пристройки),
## dark_front — насколько тёмное нутро отступает от фасада (у стен с нишами — глубже, чтобы ниши были светлыми)
static func _box(b: Bp, cx: float, cz: float, wm: int, dm: int, fl: Array, o := {}) -> void:
	var skin: Variant = o.get("skin", null)
	var tskin: Variant = o.get("trim_skin", null)
	var plain: Array = o.get("plain", [])
	var bare: Array = o.get("bare", [])
	var trim: String = o.get("trim", "SM_Bld_Trim_02")
	var f0: int = o.get("f0", 0)
	var sides: Array = o.get("sides", [0, 1, 2, 3])
	var top_trim: bool = o.get("top_trim", true)
	var end_from: int = o.get("end_from", 0)
	var hw := wm * M / 2.0
	var hd := dm * M / 2.0
	for f in fl.size():
		var y := (f + f0) * FL
		var wr: Dictionary
		if skin is Dictionary:
			wr = skin
		elif skin is Array:
			wr = skin[mini(f + f0, (skin as Array).size() - 1)]
		else:
			wr = b.floor_remap(f + f0)
		var tr: Dictionary = tskin if tskin is Dictionary else wr
		var spec: Dictionary = fl[f]
		for side: int in sides:
			var n := wm if side % 2 == 0 else dm
			var names: Array = spec.get(side, [])
			for i in n:
				var nm: String = names[i] if i < names.size() else "SM_Bld_Wall_01"
				if nm == "":
					continue
				b.remap = wr
				b.on_wall(nm, cx, cz, wm, dm, side, i, y, 0.0, true)
				if side in bare or (side in plain and f < fl.size() - 1):
					continue
				b.remap = tr
				if f < fl.size() - 1 or top_trim:
					b.on_wall(trim, cx, cz, wm, dm, side, i, y + FL - 0.33, 0.0, true)
				if f + f0 == 0 and not side in plain:
					b.on_wall("SM_Bld_Trim_05", cx, cz, wm, dm, side, i, 0.0, 0.0, true)
		if f + f0 >= end_from:
			b.remap = tr
			for c: Array in [[Vector3(cx - hw, y, cz + hd), 0.0, 0, 3], [Vector3(cx + hw, y, cz + hd), PI / 2, 0, 1], [Vector3(cx + hw, y, cz - hd), PI, 1, 2], [Vector3(cx - hw, y, cz - hd), -PI / 2, 2, 3]]:
				if (c[2] as int) in sides and (c[3] as int) in sides:
					b.add("SM_Bld_Wall_End_01", c[0], c[1], 1.0, true)
	b.remap = b.floor_remap(1)
	if o.get("dark", true):
		var h := (fl.size() + f0) * FL
		var df: float = o.get("dark_front", 0.25)
		var depth := dm * M - 0.25 - df
		b.parts.append(["#dark", b.base * Transform3D(Basis.IDENTITY.scaled(Vector3(wm * M - 0.5, h - 0.1, depth)), Vector3(cx, h / 2.0, cz + (0.25 - df) / 2.0)), {}])


## Раскраска стен своей картинкой и оттенком (кирпич конюшни, белая таверна…); черепица — как у здания
static func _skin(b: Bp, tex: String, tint := Color(1, 1, 1)) -> Dictionary:
	var r := {}
	for s0 in Bp.STUCCO:
		r[s0] = tex
	r["Roof_Tile_01"] = b.roof_tex
	if tint != Color(1, 1, 1):
		r["tints"] = {tex: tint}
	return r


## Створка двери в проёме фасада (модуль i); u — сдвиг внутри модуля (0,3 — по центру одинарного проёма)
static func _leaf(b: Bp, cx: float, cz: float, wm: int, dm: int, i: int, nm := "", u := 0.3) -> void:
	var a := b.wall_at(cx, cz, wm, dm, 0, i + u, 0.0, -0.02)
	b.add(nm if nm != "" else "SM_Bld_Door_0%d" % (1 + b.rng.randi() % 5), a[0], a[1])


## Рамка для крыш: прямоугольник x0…x1 × z0…z1 вписывается в wm×dm модулей, высота скатов растянута в ky раз.
## Возвращает прежнюю основу (вернуть после постройки крыши)
static func _frame(b: Bp, x0: float, x1: float, z0: float, z1: float, top: float, ky: float, wm: int, dm: int) -> Transform3D:
	var c := Vector3((x0 + x1) / 2.0, top, (z0 + z1) / 2.0)
	var s := Vector3((x1 - x0) / (wm * M), ky, (z1 - z0) / (dm * M))
	var keep := b.base
	b.base = keep * Transform3D(Basis.from_scale(s), c - c * s)
	return keep


## Двускатная крыша над прямоугольником: конёк вдоль X или вдоль Z (фронтоном к улице). Возвращает высоту конька.
## Дыма не добавляет (Bp.gable кладёт точку дыма на каждую крышу — у портиков и пристроек её быть не должно)
static func _gable2(b: Bp, x0: float, x1: float, z0: float, z1: float, top: float, ky := 1.5, along_z := false) -> float:
	var wm := maxi(1, int(round((x1 - x0) / M)))
	var dm := maxi(1, int(round((z1 - z0) / M)))
	var ns := b.smoke.size()
	var keep := _frame(b, x0, x1, z0, z1, top, ky, wm, dm)
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	var r := b.gable_z(cx, cz, wm, dm, top, false) if along_z else b.gable(cx, cz, wm, dm, top, false)
	b.base = keep
	b.smoke.resize(ns)
	return top + (r - top) * ky


## Вальмовая крыша (четыре ската, на длинном доме — с коньком) над прямоугольником вдоль X. Возвращает высоту конька
static func _hip(b: Bp, x0: float, x1: float, z0: float, z1: float, top: float, ky := 1.5, edges := true) -> float:
	var wm := maxi(2, int(round((x1 - x0) / M)))
	var keep := _frame(b, x0, x1, z0, z1, top, ky, wm, 2)
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	var hx := wm * M / 2.0
	var cs := Vector3(1, 0.915, 1)
	b.add_xf("SM_Bld_Roof_Base_Corner_01", Transform3D(Basis.IDENTITY.scaled(cs), Vector3(cx - hx, top, cz + M)), true)
	b.add_xf("SM_Bld_Roof_Base_Corner_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled(cs), Vector3(cx + hx, top, cz + M)), true)
	b.add_xf("SM_Bld_Roof_Base_Corner_01", Transform3D(Basis(Vector3.UP, PI).scaled(cs), Vector3(cx + hx, top, cz - M)), true)
	b.add_xf("SM_Bld_Roof_Base_Corner_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled(cs), Vector3(cx - hx, top, cz - M)), true)
	for i in range(1, wm - 1):
		b.add("SM_Bld_Roof_Base_Straight_01", Vector3(cx - hx + i * M, top, cz + M), 0.0, 1.0, true)
		b.add("SM_Bld_Roof_Base_Straight_01", Vector3(cx + hx - i * M, top, cz - M), PI, 1.0, true)
	if edges:
		for i in wm:
			b.add("SM_Bld_Roof_Edge_Straight_01", Vector3(cx - hx + i * M, top, cz + M), 0.0, 1.0, true)
	b.base = keep
	return top + 0.75 * ky


## Печная труба (беленая, с черепичной шапкой) — из неё идёт дым; p — низ трубы (чуть под скатом)
static func _chimney(b: Bp, p: Vector3, s := 1.0) -> void:
	b.add("#chimney", p, 0.0, s)
	b.smoke.append(b.base * (p + Vector3(0, 1.3 * s, 0)))


## Односкатный навес на столбах: столбы по z_post от x0 до x1, кровля поднимается к стене z_wall.
## post = "" — без столбов (козырёк на стене); beam — брус над столбами (деревянный навес)
static func _shed(b: Bp, x0: float, x1: float, z_post: float, z_wall: float, h: float, post: String, ky := 0.8, beam := true, ps := 0.8) -> void:
	var n := maxi(1, int(round((x1 - x0) / M)))
	var seg := (x1 - x0) / n
	var dir := signf(z_wall - z_post)
	var depth := absf(z_wall - z_post) + 0.35
	var yaw := 0.0 if dir < 0 else PI
	if post != "":
		for i in n + 1:
			b.add(post, Vector3(x0 + i * seg, 0, z_post), 0.0, ps)
	for i in n:
		var x := x0 + i * seg if dir < 0 else x1 - i * seg
		var p := Vector3(x, h, z_post - dir * 0.35)
		b.add_xf("SM_Bld_Roof_Base_Straight_01", Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(seg / M, ky, depth / M)), p), true)
		b.add_xf("SM_Bld_Roof_Edge_Straight_01", Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(seg / M, 1, 1)), p), true)
		if beam and post != "":
			b.add_xf("SM_Prop_Beam_01", Transform3D(Basis(Vector3.UP, yaw).scaled_local(Vector3(seg / M, 1.3, 1.3)), Vector3(p.x, h - 0.08, z_post)))


## Крытая колоннада у глухой стены (в повёрнутой рамке): вдоль x от −hl до hl стена по z = 0 с проёмами walls,
## колонны по z = d, черепичная кровля от колонн вверх к стене
static func _stoa(b: Bp, hl: float, d: float, pillar: String, walls: Array, ps := 0.8) -> void:
	var n := maxi(1, int(round(hl * 2.0 / M)))
	var seg := hl * 2.0 / n
	var ph := 3.0 * ps
	var sx := Basis.from_scale(Vector3(seg / M, 1, 1))
	for i in n:
		var x := -hl + i * seg
		b.add_xf(walls[i % walls.size()], Transform3D(sx, Vector3(x, 0, 0)), true)
		b.add_xf("SM_Bld_Wall_Tiny_01", Transform3D(sx, Vector3(x, 3.0, 0)), true)
		b.add_xf("SM_Bld_Wall_Tiny_01", Transform3D(sx, Vector3(x, ph, d)), true)
	for i in n + 1:
		b.add(pillar, Vector3(-hl + i * seg, 0, d), 0.0, ps)
	_shed(b, -hl, hl, d, 0.0, ph + 0.31, "", (3.31 - ph - 0.31) / 0.75 + 0.05, false)


## Портик с фронтоном: n колонн по z_col от x0 до x1 (стоят на высоте y0), антаблемент, крыша коньком к улице.
## ph — родная высота колонны (3 или 6 м). Возвращает высоту конька фронтона
static func _pediment(b: Bp, x0: float, x1: float, z_col: float, z_wall: float, pillar: String, ph: float, h: float, n: int, ky := 1.0, y0 := 0.0, orn := "SM_Bld_Ornament_04") -> float:
	for i in n:
		b.add(pillar, Vector3(lerpf(x0, x1, float(i) / (n - 1)), y0, z_col), 0.0, h)
	var top := y0 + ph * h
	Catalog._trim_run(b, Vector3(x0 - 0.45, top + 0.48, z_col - 0.27), Vector3(1, 0, 0), x1 - x0 + 0.9)
	Catalog._trim_run(b, Vector3(x1 - 0.27, top + 0.48, z_col + 0.26), Vector3(0, 0, -1), z_col + 0.26 - z_wall)
	Catalog._trim_run(b, Vector3(x0 + 0.27, top + 0.48, z_wall), Vector3(0, 0, 1), z_col + 0.26 - z_wall)
	var ridge := _gable2(b, x0 - 0.45, x1 + 0.45, z_wall, z_col + 0.4, top + 0.96, ky, true)
	if orn != "":
		b.add(orn, Vector3((x0 + x1) / 2.0, top + 0.96 + (ridge - top - 0.96) * 0.38, z_col + 0.45), 0.0, 0.85)
	return ridge


## Обратная сторона антаблемента (к зрителям театра): у карниза Synty рисунок только спереди, а сзади плоская
## стенка, поэтому ставим такой же ряд спина к спине, лицом к зрителям. a, len — как у Catalog._trim_run вдоль +X
static func _trim_back(b: Bp, a: Vector3, len: float) -> void:
	var n := maxi(1, int(round(len / 2.5)))
	var step := len / n
	for i in n:
		b.add_xf("SM_Bld_Trim_Large_Single_01", Transform3D(Basis(Vector3.UP, PI).scaled_local(Vector3(step / 2.5, 0.97, 1)), a + Vector3(len - step * i, 0, 0.03)))


## Статуя на постаменте
static func _statue(b: Bp, p: Vector3, yaw := 0.0, s := 0.7, plinth := "SM_Prop_Plinth_04") -> void:
	var h := 0.68 if plinth == "SM_Prop_Plinth_04" else (1.5 if plinth == "SM_Prop_Pillar_Base_02" else 1.0)
	b.add(plinth, p, 0.0, s * 1.2)
	b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), p + Vector3(0, h * s * 1.2, 0), yaw, s)


## Статуя на колонне-постаменте: постамент человечку по грудь, статуя крупнее его
static func _column_statue(b: Bp, p: Vector3, yaw := 0.0) -> void:
	b.add("SM_Prop_Pillar_Base_02", p, 0.0, 0.8)
	b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), p + Vector3(0, 1.2, 0), yaw, 0.85)


## Парус велария над трибунами: центр на угле a (от центра c), радиус rm, высота y; ткань вдоль края,
## наклонена к центру. w, d — размеры (родное полотнище 5,1 × 2,6)
static func _sail(b: Bp, c: Vector3, a: float, rm: float, y: float, w: float, d: float) -> void:
	var t := Vector3(-sin(a), 0, cos(a))
	var inward := Vector3(-cos(a), 0, -sin(a))
	var bas := Basis(t, Vector3.UP, inward) * Basis(Vector3.RIGHT, 0.35) * Basis.from_scale(Vector3(w / 5.1, 1, d / 2.6))
	var pos := c + Vector3(cos(a) * rm, y, sin(a) * rm)
	b.parts.append(["SM_Prop_Banner_Roof_02", b.base * Transform3D(bas, pos) * Transform3D(Basis.IDENTITY, Vector3(-2.55, 0.0, -1.3)), CLOTH])


## Большая бронзовая жаровня на треноге (поменьше, чем Bp.brazier(big))
static func _brazier(b: Bp, p: Vector3, s := 0.52) -> void:
	b.add("SM_Prop_Brazier_01", p, 0.0, s)
	b.add("SM_Prop_Brazier_01_Insert_01", p, 0.0, s)
	b.light(p + Vector3(0, 2.0 * s, 0))


## Фонарь на столбе (светит ночью) — как уличный фонарь-украшение, выше прохожих (CatDecor.LAMP_K)
static func _lamp_post(b: Bp, p: Vector3, yaw := 0.0) -> void:
	var k := CatDecor.LAMP_K
	b.add("#lamp_post", p, yaw, k)
	b.light(p + Vector3(0.42, 2.0, 0).rotated(Vector3.UP, yaw) * k)


## Фонарь на кронштейне у стены (yaw — куда смотрит стена)
static func _wall_lamp(b: Bp, p: Vector3, yaw := 0.0) -> void:
	b.add("#wall_lamp", p, yaw)
	b.light(p + Vector3(0, -0.2, 0.42).rotated(Vector3.UP, yaw))


## Бронзовый светильник на цепи под навесом; p — точка подвеса
static func _hanging_lamp(b: Bp, p: Vector3, s := 0.6) -> void:
	b.add("SM_Prop_Senser_03", p - Vector3(0, 1.25 * s, 0), 0.0, s)
	b.light(p - Vector3(0, 1.1 * s, 0))


## Горшок с цветами на земле
static func _pot(b: Bp, p: Vector3, s := 0.6) -> void:
	b.add("SM_Prop_FlowerPot_Fancy_01", p + Vector3(0, 0.57 * s, 0), b.rng.randf() * TAU, s)


## Амфора или кувшин
static func _jar(b: Bp, p: Vector3, s := 0.8) -> void:
	b.add(b.pick(["SM_Prop_Vase_01", "SM_Prop_Vase_02", "SM_Prop_Vase_03", "SM_Prop_Vase_05", "SM_Prop_Jar_01"]), p, b.rng.randf() * TAU, s)


## Кипарис (узкое дерево)
static func _cypress(b: Bp, p: Vector3, s := 0.5) -> void:
	b.add("SM_Env_Tree_Thin_0%d" % (1 + b.rng.randi() % 2), p, b.rng.randf() * TAU, s)


## Дерево с подкраской (оливы — серебристее)
static func _tree(b: Bp, nm: String, p: Vector3, s: Vector3, tint := Color(0.82, 0.9, 0.74)) -> void:
	b.parts.append([nm, b.base * Transform3D(Basis(Vector3.UP, b.rng.randf() * TAU).scaled(s), p), {"tint": tint}])


## Мраморная плита/подиум: центр снизу p, размер sz
static func _marble(b: Bp, p: Vector3, sz: Vector3) -> void:
	b.parts.append(["#marble", b.base * Transform3D(Basis.IDENTITY.scaled(sz), p + Vector3(0, sz.y / 2.0, 0)), {}])


## Вода (бассейн): центр снизу p, размер sz
static func _water(b: Bp, p: Vector3, sz: Vector3) -> void:
	b.parts.append(["#water", b.base * Transform3D(Basis.IDENTITY.scaled(sz), p + Vector3(0, sz.y / 2.0, 0)), {}])


## Каменный бассейн x0…x1 × z0…z1 (кратно 2,5 м): бортики, углы, вода, ступени к +Z
static func _pool(b: Bp, x0: float, x1: float, z0: float, z1: float, stairs := true) -> void:
	var nx := int(round((x1 - x0) / M))
	var nz := int(round((z1 - z0) / M))
	_water(b, Vector3((x0 + x1) / 2.0, 0.0, (z0 + z1) / 2.0), Vector3(x1 - x0, 0.12, z1 - z0))
	for i in nx:
		b.add("SM_Bld_Bath_Edge_01", Vector3(x0 + i * M, 0, z1), 0.0)
		b.add("SM_Bld_Bath_Edge_01", Vector3(x0 + (i + 1) * M, 0, z0), PI)
	for j in nz:
		b.add("SM_Bld_Bath_Edge_01", Vector3(x1, 0, z1 - j * M), PI / 2)
		b.add("SM_Bld_Bath_Edge_01", Vector3(x0, 0, z0 + j * M), -PI / 2)
	for c: Vector3 in [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x0, 0, z1), Vector3(x1, 0, z1)]:
		b.add("SM_Bld_Bath_Corner_01", c, 0.0)
	if stairs:
		b.add("SM_Bld_Bath_Stairs_01", Vector3((x0 + x1) / 2.0, 0, z1 - 0.1), PI)


# =====================================================================
#   почтовая станция — растёт с уровнем города (0…7)
# =====================================================================

## Постоялый двор государственной почты у тоннеля: ядро 3×2 модуля (контора и комнаты), справа конюшня,
## слева двор с повозкой, потом — таверна с террасой. С уровнем: второй этаж, портик с террасой, каменная
## конюшня, белый портик с фронтоном, третий этаж и двухэтажные крылья, статуи и позолота.
## Площадь перед станцией свободна: там ждут приезжие семьи (у колонн — только львы и жаровни).
## Станция — начало города: к ней приезжает повозка, перед ней ждут семьи, поэтому вся она в CENTER_K раз крупнее
## обычных построек (двери, окна и крыши выше человечка, как у вокзала в Town to City)
const CENTER_K := 1.22
## …но уже вдоль фасада, как узкие дома и лавки: в конце чертёж сжимается по X в CENTER_SX раз (_squeeze_center).
## Стены, крыши, навесы, портик, скамьи, длинный стол, ограда и повозка сжимаются; колонны, статуи, львы, жаровни,
## фонари, амфоры и горшки сохраняют форму — сдвигается только их середина. Высота остаётся крупной.
## То, что должно встать в точку x уже сжатой станции (табурет у стола, жаровня у колонны), ставится в x / CENTER_SX
const CENTER_SX := 0.8
const CENTER_FLEX := ["SM_Prop_Seat_Bench", "SM_Prop_Table_01", "SM_Prop_Cart_01", "SM_Env_Fence"]


static func _center(b: Bp, stage: int) -> void:
	var s := clampi(stage, 0, 7)
	b.base = Transform3D(Basis.from_scale(Vector3.ONE * CENTER_K), Vector3.ZERO)
	b.paint(0, false)      # охра: на жёлтой стене читается терракотовая черепица
	b.ground_style = "brick" if s >= 3 else "plain"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_01"
	b.remap = b.floor_remap(1)
	var fl := 1 if s < 1 else (2 if s < 6 else 3)     # хутор — уже два этажа: первый ранг видно издалека
	var cz := -2.5
	var top := fl * FL
	var wing := s >= 4
	var tall := s >= 6     # двухэтажные крылья
	var white := _skin(b, "Stucco_White_01", WHITE)
	# ---------- ядро ----------
	var g0 := {0: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Door_Double_01" if s < 3 else "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Window_01"],
		1: ["", ""] if wing else ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"],
		2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"],
		3: ["", ""] if wing else ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_05"]}
	var g1 := {0: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_01"],
		1: ["", ""] if tall else ["SM_Bld_Wall_Window_02", "SM_Bld_Wall_Window_06"],
		2: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_04"],
		3: ["", ""] if tall else ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_01"]}
	var g2 := {0: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_01"], 1: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_02"],
		2: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_04"], 3: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_05"]}
	var floors := [g0, g1, g2].slice(0, fl)
	_box(b, 0, cz, 3, 2, floors, {"trim": "SM_Bld_Trim_03", "plain": [1, 2] if wing else [2], "bare": [2] if tall else [], "end_from": (2 if tall else (1 if wing else 0))})
	_leaf(b, 0, cz, 3, 2, 1, "SM_Bld_Door_02", 0.1)
	b.on_wall("SM_Bld_Floor_Trim_01", 0, cz, 3, 2, 0, 1, 0.0, 0.0)
	# вальмовая крыша с навершиями и трубой
	var ridge2 := _hip(b, -3.75, 3.75, -5.0, 0.0, top, 1.5)
	_chimney(b, Vector3(2.2, top + 0.38, -3.6))
	b.add("SM_Bld_Roof_Topper_0%d" % (3 if s < 5 else 5), Vector3(-1.25, ridge2, cz), 0.0)
	b.add("SM_Bld_Roof_Topper_0%d" % (3 if s < 5 else 5), Vector3(1.25, ridge2, cz), 0.0)
	b.add("SM_Bld_Roof_Detail_01", Vector3(-1.4, top + 0.42, -1.2), 0.0, 0.7, true)
	# окна, цветы, вывеска, фонарь у двери
	for i: int in [0, 2]:
		b.on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + i % 3), 0, cz, 3, 2, 0, i + 0.5, 1.15, 0.13, false, 0.6)
		if s >= 1 and s < 3:
			b.on_wall("SM_Prop_Overhang_02", 0, cz, 3, 2, 0, i + 0.5, 2.55, 0.1)
	if s < 3:
		b.on_wall("SM_Prop_Overhang_01", 0, cz, 3, 2, 0, 1.5, 2.78, 0.12)
		b.on_wall("SM_Prop_Symbol_05", 0, cz, 3, 2, 0, 2.08, 1.55, 0.13, false, 0.55)
	_wall_lamp(b, Vector3(-1.45, 2.25, 0.05))
	if s == 2:
		# балкончики, пока нет портика с террасой
		for i: int in [0, 2]:
			b.on_wall("SM_Bld_Wall_Balcony_03", 0, cz, 3, 2, 0, i, FL, 0.2)
			b.on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + i % 3), 0, cz, 3, 2, 0, i + 0.2, FL + 1.0, 0.25, false, 0.55)
		b.on_wall("SM_Prop_Rug_Drape_01", 0, cz, 3, 2, 0, 0.75, FL + 0.95, 0.42, false, 0.8)
	if s >= 2 and s < 5:
		for i: float in [1.0, 2.0]:
			b.on_wall("SM_Prop_Banner_02_%s" % ["B", "E", "H"][b.rng.randi() % 3], 0, cz, 3, 2, 0, i, 2 * FL - 0.38, 0.06, false, 0.55)
	if s >= 6:
		b.on_wall("SM_Prop_Banner_04_%s" % ["A", "B", "C", "D"][b.rng.randi() % 4], 0, cz, 3, 2, 0, 1.5, 3 * FL - 0.3, 0.05, false, 0.9)
		for i: int in [0, 2]:
			b.on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), 0, cz, 3, 2, 0, i + 0.5, 2 * FL + 1.0, 0.13, false, 0.55)
	if s >= 7:
		for i: int in [0, 2]:
			b.on_wall("SM_Bld_Ornament_04", 0, cz, 3, 2, 0, i + 0.5, 3 * FL - 0.6, 0.12, false, 0.6)
	# ---------- правое крыло: конюшня ----------
	if s < 4:
		# деревянный навес на столбах, сено, мешки
		var keep := b.base
		b.base = keep * Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO)
		_shed(b, 0.0, 5.0, 6.05, 3.75, 2.45, "SM_Bld_Trellis_Pillar_01", 0.75)
		b.base = keep
		b.add("SM_Prop_Straw_Stack_02", Vector3(5.0, 0, -3.9), 0.4, 0.62)
		b.add("SM_Prop_Straw_Bundle_01", Vector3(4.3, 0, -2.6), 0.3)
		b.add("SM_Prop_Straw_Bundle_01", Vector3(4.6, 0, -2.2), 1.2)
		b.add("SM_Prop_Sack_Stack_02", Vector3(5.0, 0, -1.0), PI / 2, 0.85)
		b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(5.7, 0, -0.3), 0.0, 0.8)
		if s >= 1:
			b.add("SM_Prop_Bowl_07", Vector3(5.4, 0, 0.6), PI / 2, 1.0)
			_water(b, Vector3(5.4, 0.12, 0.6), Vector3(0.75, 0.16, 0.9))
	else:
		# каменная конюшня с аркой и фронтоном (с 6 уровня — с сеновалом наверху), поилка перед ней
		var sfl := 2 if tall else 1
		var st := [{0: ["SM_Bld_Wall_Door_Large_01"], 1: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"], 2: ["SM_Bld_Wall_01"]},
			{0: ["SM_Bld_Wall_Window_05"], 1: ["SM_Bld_Wall_Window_02", "SM_Bld_Wall_01"], 2: ["SM_Bld_Wall_Window_04"]}]
		var brick := _skin(b, "Building_Large_Brick_01", Color(1.0, 0.74, 0.58))
		_box(b, 5.0, cz, 1, 2, st.slice(0, sfl), {"sides": [0, 1, 2], "trim": "SM_Bld_Trim_03", "skin": brick, "plain": [2], "bare": [2] if tall else []})
		b.remap = brick
		var sr := _gable2(b, 3.75, 6.25, -5.0, 0.0, sfl * FL, 1.6, true)
		b.remap = b.floor_remap(1)
		b.add("SM_Bld_Roof_Topper_02", Vector3(5.0, sr - 0.04, -0.12), 0.0)
		b.add("SM_Prop_Bowl_07", Vector3(2.93 / CENTER_SX, 0, 0.6), PI / 2, 1.0)
		_water(b, Vector3(2.93 / CENTER_SX, 0.12, 0.6), Vector3(0.75, 0.16, 0.9))
		b.add("SM_Prop_Straw_Bundle_01", Vector3(6.5, 0, -1.2), 0.5)
		b.add("SM_Prop_Straw_Bundle_01", Vector3(6.45, 0, -0.6), 1.9)
		b.add("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(6.37, 1.6, -3.0), PI / 2)
	# ---------- левое крыло: двор с повозкой → таверна с террасой ----------
	# (эта сторона смотрит на город — её видно с обычной камеры, поэтому она нарядная)
	if s < 4:
		b.on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), 0, cz, 3, 2, 3, 0.5, 1.15, 0.13, false, 0.6)
		b.on_wall("SM_Prop_Overhang_02", 0, cz, 3, 2, 3, 1.5, 2.45, 0.1)
		b.on_wall("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 9), 0, cz, 3, 2, 3, 1.0, 1.6, 0.13)
		_wall_lamp(b, Vector3(-3.81, 2.3, -1.25), -PI / 2)
		if s >= 1:
			b.fence(-6.15, -4.85, -3.95, -1.9, false)
			for k in 3:
				b.add("SM_Env_Crop_Single_0%d" % (1 + k % 2), Vector3((-4.5 + k * 0.55) / CENTER_SX, 0, -3.4 + (k % 2) * 0.6), b.rng.randf() * TAU, 0.9)
			b.add("SM_Env_Garden_Plants_0%d" % (3 + b.rng.randi() % 3), Vector3(-4.6, 0, -4.2), 0.0, 0.6)
		else:
			b.add("SM_Prop_Vase_Pile_02", Vector3(-5.1, 0, -3.8), 0.6, 0.85)
			b.add("SM_Prop_Sack_Stack_01", Vector3(-5.0, 0, -2.4), 0.2, 0.85)
		if s >= 2:
			# увитая виноградом пергола: стол для проезжающих (лоза лежит на решётке)
			for c: Vector3 in [Vector3(-6.0, 0, -1.6), Vector3(-4.0, 0, -1.6), Vector3(-6.0, 0, 0.5), Vector3(-4.0, 0, 0.5)]:
				b.add("SM_Bld_Trellis_Pillar_01", c, 0.0, 0.78)
			b.add("SM_Bld_Trellis_Roof_01", Vector3(-3.75, 2.44, -1.8), 0.0)
			b.add_xf("SM_Env_Vine_0%d" % (1 + b.rng.randi() % 2), Transform3D(Basis(Vector3.RIGHT, -PI / 2).scaled(Vector3(0.9, 1, 1)), Vector3(-5.0, 2.72, 0.45)))
			b.add("SM_Prop_Table_04", Vector3(-5.0, 0, -0.6), 0.0, 0.9)
			for sd: float in [-1.0, 1.0]:
				b.add("SM_Prop_Seat_Stool_02", Vector3(-5.0 + sd * 0.7 / CENTER_SX, 0, -0.6), 0.0)
			b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(-5.1, 0.7, -0.55), 0.0, 0.7)
			b.add("SM_Prop_Bowl_04", Vector3(-4.8, 0.7, -0.7), 0.0, 0.8)
	else:
		var wfl := 2 if tall else 1
		var wt := [{0: ["SM_Bld_Wall_Door_Large_01"], 2: ["SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_06"]},
			{0: ["SM_Bld_Wall_Window_01"], 2: ["SM_Bld_Wall_Window_04"], 3: ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_01"]}]
		_box(b, -5.0, cz, 1, 2, wt.slice(0, wfl), {"sides": [0, 2, 3], "trim": "SM_Bld_Trim_03", "skin": white, "plain": [2], "bare": [2] if tall else []})
		b.on_wall("SM_Prop_Overhang_01", -5.0, cz, 1, 2, 0, 0.5, 2.78, 0.12)
		b.add("SM_Prop_Table_01", Vector3(-5.0, 0, 0.75), 0.0, 0.85)
		b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(-5.4, 0.66, 0.75), 0.0, 0.7)
		b.add("SM_Prop_Bowl_05", Vector3(-4.8, 0.66, 0.75), 0.0, 0.7)
		b.add("SM_Prop_Seat_Stool_02", Vector3(-5.6, 0, 1.45), 0.0)
		b.add("SM_Prop_Seat_Stool_02", Vector3(-4.4, 0, 1.45), 0.0)
		b.add("SM_Prop_Basket_Set_06", Vector3(-6.2, 0, 0.5), 0.4, 0.75)
		# бок таверны к городу: окна с цветами, скамья, фонарь
		b.on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), -5.0, cz, 1, 2, 3, 0.5, 1.15, 0.13, false, 0.6)
		b.on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), -5.0, cz, 1, 2, 3, 1.5, 1.15, 0.13, false, 0.6)
		b.on_wall("SM_Prop_Overhang_01", -5.0, cz, 1, 2, 3, 1.0, 2.6, 0.1)
		b.add("SM_Prop_Seat_Bench_01", Vector3(-6.7, 0, -2.5), -PI / 2, 0.85)
		_jar(b, Vector3(-6.65, 0, -0.9), 0.75)
		_wall_lamp(b, Vector3(-6.31, 2.3, -2.5), -PI / 2)
		var wtop := wfl * FL
		if not tall:
			# терраса с перголой и ложем
			b.add("SM_Bld_Roof_Base_Flat_02", Vector3(-6.25, wtop - 0.68, 0.0), 0.0)
			b.add("SM_Bld_Roof_Base_Flat_02", Vector3(-6.25, wtop - 0.68, -2.5), 0.0)
			b.remap = white
			for side: int in [0, 2, 3]:
				for i in (1 if side % 2 == 0 else 2):
					b.on_wall("SM_Bld_Wall_Balcony_03", -5.0, cz, 1, 2, side, i, wtop, 0.0, true)
			b.remap = b.floor_remap(1)
			b.roof_pergola(-6.25, -2.5, wtop)
			b.add("SM_Env_Ivy_Draped_Flowers_02", Vector3(-5.0, wtop + 0.9, 0.12), 0.0)
		else:
			b.remap = white
			var wr := _gable2(b, -6.25, -3.75, -5.0, 0.0, wtop, 1.6, true)
			b.remap = b.floor_remap(1)
			b.add("SM_Bld_Roof_Topper_02", Vector3(-5.0, wr - 0.04, -0.12), 0.0)
			b.on_wall("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 5), -5.0, cz, 1, 2, 3, 1.5, 1.8, 0.13)
	# повозка: у двора, потом — в воротах конюшни
	var cp := Vector3(5.05, 0, 0.75) if wing else Vector3(-5.0, 0, 0.9)
	var cy := PI if wing else (0.0 if s >= 2 else -0.1)   # ровно: в воротах конюшни и между столбами перголы
	b.add("SM_Prop_Cart_01", cp, cy, 0.85)
	b.add("SM_Prop_Cart_01_Insert_0%d" % (2 if s % 2 == 0 else 3), cp, cy, 0.85)
	# ---------- портик: с 3 уровня колонны с террасой наверху, с 5 — белый портик с фронтоном ----------
	if s >= 3 and s < 5:
		for i in 4:
			b.add("SM_Bld_Pillar_02", Vector3(-3.75 + i * M, 0, 2.5), 0.0, 0.92)
		for x: float in [-3.75, 3.75]:
			b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(x, 0, 2.5), b.rng.randf() * TAU, 0.92)
		b.remap = white
		for i in 3:
			var x := -3.75 + i * M
			b.add("SM_Bld_Wall_Tiny_01", Vector3(x, 2.76, 2.5), 0.0, 1.0, true)
			b.add_xf("SM_Bld_Roof_Base_Flat_02", Transform3D(Basis.from_scale(Vector3(1, 1, 1.08)), Vector3(x, 2.37, 2.7)))
			b.add("SM_Bld_Wall_Balcony_03", Vector3(x, 3.1, 2.5), 0.0, 1.0, true)
		b.add("SM_Bld_Wall_Balcony_03", Vector3(-3.75, 3.1, 0.0), -PI / 2, 1.0, true)
		b.add("SM_Bld_Wall_Balcony_03", Vector3(3.75, 3.1, 2.5), PI / 2, 1.0, true)
		b.remap = b.floor_remap(1)
		for i in 3:
			b.add("SM_Prop_Drapery_0%d" % (1 + i), Vector3(-2.5 + i * M, 2.62, 2.66), 0.0)
		# на террасе: цветы по углам, ковёр на перилах
		_pot(b, Vector3(-3.3, 3.12, 2.15), 0.6)
		_pot(b, Vector3(3.3, 3.12, 2.15), 0.6)
		b.add("SM_Prop_Rug_Drape_01", Vector3(1.6, 4.02, 2.66), 0.0, 0.8)
	elif s >= 5:
		b.remap = white
		var pr := _pediment(b, -3.75, 3.75, 2.5, 0.0, "SM_Bld_Pillar_04", 3.0, 1.0, 4, 1.15, 0.0, "")
		b.remap = b.floor_remap(1)
		b.add("SM_Bld_Ornament_04", Vector3(0, 3.96 + (pr - 3.96) * 0.36, 3.0), 0.0, 1.1)
		for x: float in [-3.75, 3.75]:
			b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(x, 0, 2.5), b.rng.randf() * TAU)
		for i in 3:
			b.add("SM_Prop_Drapery_0%d" % (1 + i), Vector3(-2.5 + i * M, 2.95, 2.8), 0.0)
		b.add("SM_Prop_Symbol_05", Vector3(0, 3.22, 2.79), 0.0, 0.55)
		if s >= 6:
			b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, pr - 0.05, 2.85), 0.0, 0.75)
		if s == 6:
			b.add("SM_Bld_Roof_Topper_05", Vector3(-4.1, 4.0, 2.75), 0.0)
			b.add("SM_Bld_Roof_Topper_05", Vector3(4.1, 4.0, 2.75), 0.0)
		elif s >= 7:
			b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(-4.1, 4.0, 2.85), 0.0, 0.45)
			b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(4.1, 4.0, 2.85), 0.0, 0.45)
	# скамьи у стены по сторонам двери, у их концов — амфора и горшок (с 4 уровня справа поилка, горшок не нужен)
	if s >= 3:
		b.add("SM_Prop_Seat_Bench_01", Vector3(-2.3, 0, 0.5), 0.0, 0.9)
		b.add("SM_Prop_Seat_Bench_01", Vector3(2.3, 0, 0.5), 0.0, 0.9)
		_jar(b, Vector3(-2.8 / CENTER_SX, 0, 0.45))
		if not wing:
			_pot(b, Vector3(2.8 / CENTER_SX, 0, 0.5))
	else:
		b.add("SM_Prop_Seat_Bench_01", Vector3(-2.3, 0, 0.55), 0.0, 0.9)
		_jar(b, Vector3(2.0, 0, 0.45))
		_jar(b, Vector3(2.05 / CENTER_SX, 0, 0.62), 0.7)
		_pot(b, Vector3(-2.72 / CENTER_SX, 0, 0.5))
		b.add("SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(-2.9, 0.38, 1.6), 0.0, 0.8)
	# ---------- перед станцией: верстовой столб, знамя на шесте, свет, львы ----------
	# всё — у стены, между колоннами или по краям (|x| ≥ 4,3): площадь — для ждущих семей
	b.add("SM_Prop_Plinth_02", Vector3(-6.75, 0, 1.6), 0.0, 1.25)
	b.add("SM_Prop_Pillar_Top_01", Vector3(-6.75, 1.26, 1.6), 0.0, 0.5)
	b.add("SM_Prop_Pole_02", Vector3(6.55, 0, 1.6), 0.0, 1.05)
	b.add("SM_Prop_Banner_03_%s" % ["A", "C", "E", "G"][s % 4], Vector3(6.55, 3.05, 1.7), 0.0, 0.8)
	match s:
		0:
			b.brazier(Vector3(3.4, 0, 1.2))
		1, 2:
			_lamp_post(b, Vector3(-3.8, 0, 1.3), 0.0)
			_lamp_post(b, Vector3(3.8, 0, 1.3), PI)
		3:
			b.brazier(Vector3(-2.5, 0, 2.15))
			b.brazier(Vector3(2.5, 0, 2.15))
		4:
			# за крайними колоннами, фонарь — наружу (не в колонну)
			_lamp_post(b, Vector3(-3.75 / CENTER_SX, 0, 2.4), PI)
			_lamp_post(b, Vector3(3.75 / CENTER_SX, 0, 2.4), 0.0)
		_:
			_brazier(b, Vector3(-3.96 / CENTER_SX, 0, 2.4))
			_brazier(b, Vector3(3.96 / CENTER_SX, 0, 2.4))
	if s >= 4:
		# львы у входа, ближе к средним колоннам: в боковых пролётах место для стража (Catalog._actors)
		b.add("SM_Prop_Statue_Lion_01", Vector3(-1.75 / CENTER_SX, 0, 2.05), 0.0, 0.32)
		b.add("SM_Prop_Statue_Lion_01", Vector3(1.75 / CENTER_SX, 0, 2.05), 0.0, 0.32)
	b.door = Vector3(0, 0, 0.9 if s < 3 else 3.4) * CENTER_K
	_squeeze_center(b)


## Сжать готовую станцию вдоль фасада в CENTER_SX раз (см. CENTER_SX): гибкие детали — как у лавок (CatShops._flex)
## и CENTER_FLEX, остальные сохраняют форму. Огни, дым и вход — следом
static func _squeeze_center(b: Bp) -> void:
	var sx := CENTER_SX
	var S := Basis.from_scale(Vector3(sx, 1, 1))
	var k := Vector3(sx, 1, 1)
	for p: Array in b.parts:
		var nm: String = p[0]
		var xf: Transform3D = p[1]
		var flex := CatShops._flex(nm)
		for f: String in CENTER_FLEX:
			flex = flex or nm.begins_with(f)
		if flex:
			p[1] = Transform3D(S * xf.basis, xf.origin * k)
		else:
			var c := xf * Bp.model_aabb(nm).get_center()
			p[1] = Transform3D(xf.basis, xf.origin + Vector3(c.x * (sx - 1.0), 0, 0))
	for i in b.lights.size():
		b.lights[i] = b.lights[i] * k
	for i in b.smoke.size():
		b.smoke[i] = b.smoke[i] * k
	b.door = b.door * k


# =====================================================================
#   склад
# =====================================================================

## Кирпичные хранилища (horrea) в два этажа: три арочных пролёта, грузовая дверь с балкой-подъёмником
## (корзина на верёвке), навесы над пролётами, мешки, амфоры, корзины, сбоку — гружёная повозка
static func _warehouse(b: Bp) -> void:
	b.paint(-1, false)
	b.roof_tex = "Roof_Tile_03"
	var brick := _skin(b, "Building_Large_Brick_01", Color(1.0, 0.76, 0.6))
	b.remap = brick
	var cz := -1.9
	_box(b, 0, cz, 3, 2, [
		{0: ["SM_Bld_Wall_Door_Large_01", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Door_Large_01"], 1: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"]},
		{0: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_Door_04", "SM_Bld_Wall_Window_04"], 1: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_Window_04"],
			2: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_04"], 3: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_Window_04"]}], {"trim": "SM_Bld_Trim_04", "skin": brick})
	_leaf(b, 0, cz, 3, 2, 1, "SM_Bld_Door_01", 0.05)
	b.remap = brick
	var ridge := _gable2(b, -3.75, 3.75, cz - 2.5, cz + 2.5, 2 * FL, 1.4)
	b.add("SM_Bld_Roof_Detail_02", Vector3(1.2, 2 * FL + 0.42, cz + 1.0), 0.0, 0.85, true)
	b.add("SM_Bld_Roof_Detail_01", Vector3(-2.3, 2 * FL + 0.35, cz - 1.6), PI, 0.8, true)
	b.remap = b.floor_remap(1)
	_chimney(b, Vector3(2.2, ridge - 0.5, cz - 0.4))
	var fz := cz + 2.5
	# подъёмник над грузовой дверью: балка, верёвка до корзины, мешки на пороге
	b.add_xf("SM_Prop_Beam_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled_local(Vector3(0.62, 1.4, 1.4)), Vector3(0, FL + 2.8, fz - 0.1)))
	b.add_xf("SM_Prop_Pole_01", Transform3D(Basis.from_scale(Vector3(0.3, 0.45, 0.3)), Vector3(0, FL + 1.42, fz + 1.3)))
	b.add("SM_Prop_Basket_02", Vector3(0, FL + 0.86, fz + 1.3), 0.4, 0.95)
	b.add("SM_Prop_Sack_Stack_02", Vector3(0, FL, fz - 0.05), 0.0, 0.55)
	# навесы над боковыми пролётами, вывеска, факелы
	for i: int in [0, 2]:
		b.on_wall("SM_Prop_Overhang_01", 0, cz, 3, 2, 0, i + 0.5, 2.85, 0.14)
	b.on_wall("SM_Prop_Symbol_0%d" % (5 + b.rng.randi() % 4), 0, cz, 3, 2, 0, 1.5, 2.72, 0.16, false, 0.55)
	b.torch_pair(0, cz, 3, 2, 1.5)
	# товары у стены (не дальше метра от фасада — на мостовую не вылезают)
	b.add("SM_Prop_Sack_Stack_01", Vector3(-2.6, 0, fz + 0.45), 0.0, 0.85)
	b.add("SM_Prop_Sack_Stack_02", Vector3(-2.65, 0.66, fz + 0.45), 0.25, 0.7)
	b.add("SM_Prop_Sack_05", Vector3(-1.6, 0, fz + 0.4), 0.6, 0.9)
	for k in 3:
		b.add("SM_Prop_Vase_0%d" % [1, 3, 6][k], Vector3(1.75 + k * 0.5, 0, fz + 0.35), b.rng.randf() * TAU, 0.85)
	b.add("SM_Prop_Basket_Set_06", Vector3(3.3, 0, fz + 0.45), 0.3, 0.8)
	b.add("SM_Prop_Jar_01", Vector3(-3.4, 0, fz + 0.4), 0.0, 0.8)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(-1.75, 0.55, fz + 0.38), 0.0, 0.6)
	# повозка с грузом и амфоры у правой стены, лестница у левой
	b.add("SM_Prop_Cart_01", Vector3(4.7, 0, cz + 0.85), 0.05, 0.82)
	b.add("SM_Prop_Cart_01_Insert_02", Vector3(4.7, 0, cz + 0.85), 0.05, 0.82)
	b.add("SM_Prop_Vase_Pile_02", Vector3(4.55, 0, cz - 1.7), 0.0, 0.75)
	b.add_xf("SM_Prop_Ladder_01", Transform3D(Basis(Vector3.UP, PI / 2) * Basis(Vector3.RIGHT, -0.2), Vector3(4.3, 0, cz - 0.9)))
	b.add("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 9), Vector3(-3.87, 1.7, cz - 0.8), -PI / 2)
	b.door = Vector3(0, 0, fz + 0.9)


# =====================================================================
#   науки: скрипторий → школа → библиотека → академия
# =====================================================================

## Скрипторий-книжная лавка: узкий голубой дом в два этажа с фронтоном к улице, открытая лавка с полками свитков,
## под красным навесом на тонких столбиках — стол писца (писец сидит на табурете в (1,2, 0, 1,7) лицом к столу)
static func _scriptorium(b: Bp) -> void:
	b.paint(4, false)
	b.ground_style = "pattern"
	b.roof_tex = "Roof_Tile_12"
	b.remap = b.floor_remap(1)
	var cz := -1.25
	_box(b, 0, cz, 2, 1, [
		{0: ["SM_Bld_Wall_Door_04", "SM_Bld_Wall_Door_Large_02"], 1: ["SM_Bld_Wall_Window_06"], 2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_01"]},
		{0: ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_02"], 1: ["SM_Bld_Wall_Window_04"], 2: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_02"]}], {"trim": "SM_Bld_Trim_02"})
	_leaf(b, 0, cz, 2, 1, 0, "SM_Bld_Door_04")
	b.on_wall("SM_Bld_Floor_Trim_01", 0, cz, 2, 1, 0, 0, 0.0, 0.0)
	var ridge := _gable2(b, -2.5, 2.5, -2.5, 0.0, 2 * FL, 1.6, true)
	b.add("SM_Bld_Roof_Topper_05", Vector3(0, ridge - 0.05, -0.1), 0.0)
	b.add("SM_Bld_Ornament_0%d" % [1, 2, 4, 5][b.rng.randi() % 4], Vector3(0, 2 * FL + 0.42, 0.06), 0.0, 0.55)
	_chimney(b, Vector3(0.9, ridge - 0.75, -1.9), 0.9)
	# полки со свитками в открытой лавке, стол писца, табурет
	b.add("SM_Prop_Shelf_Scroll_01", Vector3(1.25, 0, 0.12), 0.0, 0.85)
	b.add("SM_Prop_Shelf_Scroll_01_Insert_0%d" % (1 + b.rng.randi() % 2), Vector3(1.25, 0, 0.12), 0.0, 0.85)
	b.add("SM_Prop_Table_05", Vector3(1.2, 0, 1.0), PI / 2, 0.95)
	b.add("SM_Prop_Scroll_Pile_0%d" % [1, 3, 5][b.rng.randi() % 3], Vector3(0.95, 0.74, 1.0), 0.3, 0.55)
	b.add("SM_Prop_Scroll_01", Vector3(1.45, 0.76, 1.05), 1.2, 0.9)
	b.add("SM_Prop_Seat_Stool_01", Vector3(1.2, 0, 1.7), 0.0, 0.95)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(2.2, 0, 1.25), 0.0, 0.7)
	b.add("SM_Prop_Scroll_Pile_02", Vector3(2.2, 0.48, 1.25), 0.0, 0.8)
	# красный тканевый навес на двух тонких столбиках
	b.add_xf("SM_Prop_Banner_Roof_01", Transform3D(Basis(Vector3.RIGHT, 0.16).scaled(Vector3(1, 1, 0.92)), Vector3(0.05, 2.66, 0.16)))
	for x: float in [0.15, 2.45]:
		b.add_xf("SM_Bld_Pillar_06", Transform3D(Basis.from_scale(Vector3(0.55, 0.887, 0.55)), Vector3(x, 0, 2.25)))
	# у двери: фонарь, вывеска, цветы; на втором этаже — балкончик
	_wall_lamp(b, Vector3(-0.1, 2.3, 0.08))
	b.on_wall("SM_Prop_Symbol_0%d" % (1 + b.rng.randi() % 4), 0, cz, 2, 1, 0, 0.12, 1.7, 0.14, false, 0.55)
	_pot(b, Vector3(-2.15, 0, 0.45))
	b.on_wall("SM_Bld_Wall_Balcony_03", 0, cz, 2, 1, 0, 0, FL, 0.2)
	b.on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), 0, cz, 2, 1, 0, 0.18, FL + 1.0, 0.25, false, 0.55)
	b.on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), 0, cz, 2, 1, 0, 1.5, FL + 1.05, 0.13, false, 0.55)
	b.add("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 9), Vector3(-2.62, 1.7, -1.3), -PI / 2)
	b.door = Vector3(-1.25, 0, 1.6)


## Школа грамматика: лимонный дом в два этажа под вальмовой крышей (наверху — зал с балкончиком), перед ним
## увитая виноградом пергола-«пергула»: под ней скамьи учеников, кресло учителя, свитки, лира, солнечные часы,
## бронзовые светильники (учитель стоит в (0, 0, 2,6) лицом к ученикам)
static func _school(b: Bp) -> void:
	b.paint(3, false)
	b.ground_style = "plain"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_01"
	b.remap = b.floor_remap(1)
	var cz := -2.5
	_box(b, 0, cz, 3, 2, [
		{0: ["SM_Bld_Wall_01", "SM_Bld_Wall_Door_Double_01", "SM_Bld_Wall_Window_05"], 1: ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_01"],
			2: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_01"], 3: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_05"]},
		{0: ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_05"], 1: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_05"],
			2: ["SM_Bld_Wall_Window_04", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_04"], 3: ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_01"]}], {"trim": "SM_Bld_Trim_04", "plain": [2]})
	_leaf(b, 0, cz, 3, 2, 1, "SM_Bld_Door_05", 0.1)
	b.on_wall("SM_Bld_Floor_Trim_01", 0, cz, 3, 2, 0, 1, 0.0, 0.0)
	var ridge := _hip(b, -3.75, 3.75, -5.0, 0.0, 2 * FL, 1.55)
	b.add("SM_Bld_Roof_Topper_01", Vector3(-1.25, ridge, cz), 0.0)
	b.add("SM_Bld_Roof_Topper_01", Vector3(1.25, ridge, cz), 0.0)
	_chimney(b, Vector3(-2.2, 2 * FL + 0.45, cz - 1.4))
	# зал наверху: балкончик с ковром, цветы под окнами, вывеска-знамя
	b.on_wall("SM_Bld_Wall_Balcony_03", 0, cz, 3, 2, 0, 1, FL, 0.2)
	b.on_wall("SM_Prop_Rug_Drape_01", 0, cz, 3, 2, 0, 1.3, FL + 0.95, 0.42, false, 0.8)
	for i: int in [0, 2]:
		b.on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), 0, cz, 3, 2, 0, i + 0.5, FL + 1.05, 0.13, false, 0.55)
	b.wall_banner(0, cz, 3, 2, 1.0, 2 * FL - 0.35)
	b.on_wall("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 9), 0, cz, 3, 2, 3, 0.6, 3.6, 0.13)
	# фреска-карта на глухом простенке, вывеска, цветы, фонарь у двери
	b.on_wall("SM_Prop_Mural_02", 0, cz, 3, 2, 0, 0.5, 1.45, 0.12)
	b.on_wall("SM_Prop_Symbol_%02d" % (9 + b.rng.randi() % 4), 0, cz, 3, 2, 0, 1.5, 2.6, 0.14, false, 0.5)
	b.on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), 0, cz, 3, 2, 0, 2.5, 1.15, 0.13, false, 0.6)
	_wall_lamp(b, Vector3(1.55, 2.25, 0.06))
	# пергола: по углам — мраморные колонки, между ними — деревянные столбы; решётка, на ней лежит лоза
	for x: float in [-3.6, 3.6]:
		b.add("SM_Bld_Pillar_06", Vector3(x, 0, 2.95), 0.0, 0.82)
		b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(x, 0, 2.95), b.rng.randf() * TAU, 0.85)
	for x: float in [-1.2, 1.2]:
		b.add("SM_Bld_Trellis_Pillar_01", Vector3(x, 0, 2.95), 0.0, 0.78)
	b.add_xf("SM_Bld_Trellis_Roof_Large_02", Transform3D(Basis.from_scale(Vector3(0.98, 1, 0.6)), Vector3(-3.6, 2.44, 0.09)))
	for k in 4:
		var vx := -1.9 if k % 2 == 0 else 1.9
		var vz := 3.0 if k < 2 else 1.55
		b.add_xf("SM_Env_Vine_0%d" % (1 + (k + b.rng.randi()) % 2), Transform3D(Basis(Vector3.UP, 0.0 if k % 2 == 0 else PI) * Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3(1.3, 0.95, 1.0)), Vector3(vx, 2.74, vz if k % 2 == 0 else vz - 1.45)))
	_hanging_lamp(b, Vector3(-2.4, 2.44, 1.5))
	_hanging_lamp(b, Vector3(2.4, 2.44, 1.5))
	# скамьи учеников (лицом к учителю), на них — свитки и лира
	for r in 2:
		for x: float in [-1.55, 1.55]:
			b.add("SM_Prop_Seat_Bench_01", Vector3(x, 0, 0.95 + r * 0.85), 0.0, 1.0)
	b.add("SM_Prop_Scroll_Pile_02", Vector3(-1.9, 0.49, 0.95), 0.4, 0.8)
	b.add("SM_Prop_Scroll_Pile_04", Vector3(1.2, 0.49, 1.8), -0.3, 0.8)
	b.add("SM_Prop_Lyre_01", Vector3(1.95, 0.6, 0.95), 0.2, 0.8)
	# кресло учителя и корзина-капса со свитками
	b.add("SM_Prop_Seat_Chair_03", Vector3(0.85, 0, 2.75), PI, 0.75)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(-0.85, 0, 2.8), 0.0, 0.65)
	b.add("SM_Prop_Scroll_Pile_06", Vector3(-0.85, 0.4, 2.8), 0.0, 0.5)
	# солнечные часы, цветы, кипарисы по углам
	b.add("SM_Prop_Sundial_01", Vector3(-3.0, 0, 1.55), 0.0, 0.75)
	_pot(b, Vector3(3.05, 0, 1.4))
	_pot(b, Vector3(3.1, 0, 0.55), 0.5)
	_cypress(b, Vector3(-4.35, 0, -0.6), 0.45)
	_cypress(b, Vector3(4.35, 0, -0.6), 0.45)
	b.door = Vector3(0, 0, 3.8)


## Библиотека: двухэтажный зал цвета тёплого песка, в светлых нишах фасада — статуи мудрецов (как у библиотеки
## Цельса), в центре — портик с фронтоном на мраморном подиуме, статуи на постаментах, мраморные скамьи, кипарисы
static func _library(b: Bp) -> void:
	b.paint(6, false)
	b.tint = Color(1.0, 0.87, 0.64)
	b.ground_style = "pattern"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_01"
	b.remap = b.floor_remap(1)
	var cz := -2.6
	_box(b, 0, cz, 4, 2, [
		{0: ["SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Alcove_01"], 1: ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_01"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_05"]},
		{0: ["SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Alcove_01"], 1: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_01"],
			2: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_01", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_01"], 3: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_01"]}],
		{"trim": "SM_Bld_Trim_02", "plain": [2], "dark_front": 0.65})
	var fz := cz + 2.5
	# статуи в нишах обоих этажей
	for f in 2:
		for i: int in [0, 3]:
			var a := b.wall_at(0, cz, 4, 2, 0, i + 0.5, f * FL + 0.22, -0.32)
			b.add("SM_Prop_Statue_0%d" % (1 + (i + f * 2 + b.rng.randi()) % 7), a[0], a[1], NICHE)
	var ridge := _gable2(b, -5.0, 5.0, cz - 2.5, fz, 2 * FL, 1.3)
	for x: float in [-4.85, 4.85]:
		b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(x, ridge - 0.12, cz), 0.0, 0.45)
	b.add("SM_Bld_Roof_Detail_01", Vector3(2.3, 2 * FL + 0.4, fz - 0.9), 0.0, 0.8, true)
	b.smoke.clear()
	_chimney(b, Vector3(-2.8, ridge - 0.65, cz - 0.6))
	# цветы под окнами верхнего зала
	for i: int in [1, 2]:
		b.on_wall("SM_Prop_FlowerPot_Hanging_0%d" % (4 + b.rng.randi() % 3), 0, cz, 4, 2, 0, i + 0.5, FL + 1.0, 0.16, false, 0.55)
	# мраморный подиум, ступень и портик с фронтоном над двумя средними пролётами
	_marble(b, Vector3(0, 0, fz + 1.35), Vector3(6.4, 0.32, 2.7))
	for x: float in [-3.2, -0.7, 1.8]:
		b.add_xf("SM_Bld_Ground_Edge_01", Transform3D(Basis.IDENTITY.scaled(Vector3(0.56 if x > 1.0 else 1.0, 1.4, 1.0)), Vector3(x, 0.1, fz + 2.72)))
	var pr := _pediment(b, -2.6, 2.6, fz + 2.35, fz, "SM_Bld_Pillar_02", 3.0, 0.92, 4, 1.05, 0.32)
	b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, pr - 0.05, fz + 2.7), 0.0, 0.55)
	var pt := 0.32 + 3.0 * 0.92 + 0.96
	b.add("SM_Bld_Roof_Topper_05", Vector3(-3.0, pt, fz + 2.62), 0.0)
	b.add("SM_Bld_Roof_Topper_05", Vector3(3.0, pt, fz + 2.62), 0.0)
	b.add("SM_Prop_Drapery_01", Vector3(0, 2.95, fz + 2.5), 0.0, 0.8)
	# по сторонам: статуи на колоннах-постаментах, плющ, мраморные скамьи, свитки
	_column_statue(b, Vector3(-4.0, 0, fz + 1.9))
	_column_statue(b, Vector3(4.0, 0, fz + 1.9))
	b.add("SM_Prop_Seat_Bench_03", Vector3(-4.1, 0, fz + 0.5), 0.0, 0.85)
	b.add("SM_Prop_Seat_Bench_03", Vector3(4.1, 0, fz + 0.5), 0.0, 0.85)
	b.add("SM_Prop_Scroll_Pile_0%d" % [1, 5, 6][b.rng.randi() % 3], Vector3(-4.6, 0.55, fz + 0.5), 0.0, 0.6)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(4.9, 0, fz + 1.0), 0.0, 0.65)
	b.add("SM_Prop_Scroll_Pile_03", Vector3(4.9, 0.42, fz + 1.0), 0.0, 0.6)
	b.add("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 9), Vector3(-5.12, 2.2, cz + 1.0), -PI / 2)
	b.add("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 9), Vector3(5.12, 1.6, cz - 1.2), PI / 2)
	_cypress(b, Vector3(-5.6, 0, fz + 0.4), 0.5)
	_cypress(b, Vector3(5.6, 0, fz + 0.4), 0.5)
	_wall_lamp(b, Vector3(-2.75, 2.4, fz + 0.06))
	_wall_lamp(b, Vector3(2.75, 2.4, fz + 0.06))
	b.wall_banner(0, cz, 4, 2, 1.0, 2 * FL - 0.35)
	b.wall_banner(0, cz, 4, 2, 3.0, 2 * FL - 0.35)
	b.door = Vector3(0, 0, fz + 3.5)


## Академия: зал философов с высоким портиком (колонны в два этажа, фронтон), перед ним двор-перистиль:
## сад с крестом мраморных дорожек, крытые колоннады по бокам (снаружи — окна, плющ, фонари), круглая
## беседка-толос со статуей на перекрёстке, полукруглые скамьи, оливы; по фронту — ограда и ворота с фронтончиком
static func _academy(b: Bp) -> void:
	b.paint(6, false)
	b.tint = Color(1.0, 0.95, 0.86)
	b.ground_style = "pattern"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_05"
	b.remap = b.floor_remap(1)
	var cz := -5.0
	_box(b, 0, cz, 5, 2, [
		{0: ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Window_05"],
			1: ["SM_Bld_Wall_Window_05", "SM_Bld_Wall_01"], 2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_05"]},
		{0: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_01"],
			1: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_01"], 2: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_01", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_01"], 3: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_01"]}],
		{"trim": "SM_Bld_Trim_02", "plain": [2], "bare": [2], "dark_front": 0.65})
	var fz := cz + 2.5
	for i: int in [1, 3]:
		var a := b.wall_at(0, cz, 5, 2, 0, i + 0.5, 0.22, -0.32)
		b.add("SM_Prop_Statue_0%d" % (1 + (i + b.rng.randi()) % 7), a[0], a[1], NICHE)
	var ridge := _hip(b, -6.25, 6.25, cz - 2.5, fz, 2 * FL, 1.3)
	_chimney(b, Vector3(-4.0, 2 * FL + 0.42, cz - 0.8))
	# портик: четыре колонны в два этажа, антаблемент, фронтон с медальоном и статуей
	var pr := _pediment(b, -3.75, 3.75, fz + 2.3, fz, "SM_Bld_Pillar_Large_01", 6.0, 1.0, 4, 1.1)
	b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, pr - 0.05, fz + 2.6), 0.0, 0.7)
	b.add("SM_Prop_Banner_Large_01", Vector3(0, 6.2, fz + 2.65), 0.0, 0.62)
	b.add("SM_Env_Ivy_Pillar_Flowers_04", Vector3(-3.75, 0, fz + 2.3), 0.5, 0.95)
	b.add("SM_Env_Ivy_Pillar_Flowers_04", Vector3(3.75, 0, fz + 2.3), 2.5, 0.95)
	# двор: мраморный пол портика, крест дорожек, полы колоннад — между ними сад
	var z0 := fz + 0.05
	var z1 := 5.4
	var zp := fz + 2.95                 # край пола портика
	var tz := (zp + z1) / 2.0           # перекрёсток дорожек — там толос
	_marble(b, Vector3(0, 0, (z0 + zp) / 2.0), Vector3(9.3, 0.06, zp - z0))
	_marble(b, Vector3(0, 0, (zp + z1) / 2.0), Vector3(1.6, 0.05, z1 - zp))
	_marble(b, Vector3(0, 0, tz), Vector3(9.3, 0.05, 1.6))
	for side: float in [-1.0, 1.0]:
		_marble(b, Vector3(side * 5.45, 0, (z0 + z1) / 2.0), Vector3(1.6, 0.06, z1 - z0))
	# крытые колоннады по бокам (кровля поднимается наружу к стене-ограде; снаружи — окна, плющ, фонарь)
	for side: float in [-1.0, 1.0]:
		var keep := b.base
		b.base = keep * Transform3D(Basis(Vector3.UP, -side * PI / 2), Vector3(side * 6.25, 0, (z0 + z1) / 2.0))
		# в повёрнутой рамке: x — вдоль двора, z — от боковой стены (0) внутрь (+)
		var hl := (z1 - z0) / 2.0
		_stoa(b, hl, 1.6, "SM_Bld_Pillar_01", ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Window_01"])
		b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, 0.22, -0.32), 0.0, 0.78)
		b.add("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 9), Vector3(-1.75, 1.9, -0.14), PI)
		_wall_lamp(b, Vector3(1.75, 2.35, -0.12), PI)
		b.base = keep
	# толос со статуей и полукруглые скамьи-экседры
	b.add("SM_Prop_Pergola_01", Vector3(0, 0.05, tz), 0.0, 0.55)
	b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(0, 0.05, tz), PI, 0.75)
	b.add("SM_Prop_Seat_Bench_04", Vector3(-2.9, 0.05, tz), PI / 2, 0.72)
	b.add("SM_Prop_Seat_Bench_04", Vector3(2.9, 0.05, tz), -PI / 2, 0.72)
	# сад: клумбы у портика, кусты и цветы, оливы у ворот, кипарисы у портика
	var qb := (zp + tz - 0.8) / 2.0
	var qf := (tz + 0.8 + z1) / 2.0
	for side: float in [-1.0, 1.0]:
		b.add("SM_Prop_FlowerBed_0%d" % (1 + b.rng.randi() % 2), Vector3(side * 2.4, 0.38, qb), 0.0, 0.85)
		b.add("SM_Env_Garden_Plants_0%d" % (3 + b.rng.randi() % 5), Vector3(side * 1.45, 0, qf + 0.3), b.rng.randf() * TAU, 0.55)
		_tree(b, "SM_Env_Tree_03", Vector3(side * 3.1, 0, qf), Vector3(0.36, 0.32, 0.36), Color(0.82, 0.92, 0.9))
		_cypress(b, Vector3(side * 5.2, 0, fz + 0.6), 0.5)
	# ограда по фронту, ворота — две колонны и фронтончик с медальоном
	for x: float in [-6.25, -3.75, 1.25, 3.75]:
		b.add("SM_Bld_Wall_Balcony_05", Vector3(x, 0, z1), 0.0, 1.0, true)
	var gr := _pediment(b, -1.35, 1.35, z1, z1 - 0.6, "SM_Bld_Pillar_02", 3.0, 0.85, 2, 2.0, 0.0, "")
	b.add("SM_Bld_Ornament_04", Vector3(0, 3.51 + (gr - 3.51) * 0.33, z1 + 0.47), 0.0, 0.5)
	b.add("SM_Prop_Drapery_0%d" % (1 + b.rng.randi() % 3), Vector3(0, 2.52, z1 + 0.3), 0.0, 1.05)
	_lamp_post(b, Vector3(-2.3, 0, z1 + 0.1), PI)
	_lamp_post(b, Vector3(2.3, 0, z1 + 0.1), 0.0)
	b.door = Vector3(0, 0, z1 + 0.9)


# =====================================================================
#   хозяйство
# =====================================================================

## Пшеничное поле: изгородь с воротами, золотая пшеница сзади, зелёные грядки поперёк поля — работники
## ((−2,3; −1,2) и (1,4; 1,6)) стоят между рядами; хижина работников с навесом, стога, колодец, плуг, серпы,
## корзины. Хижина, стога и колодец — то справа, то слева (у разных полей по-разному)
static func _farm(b: Bp) -> void:
	b.paint(9, false)
	b.ground_style = "plain"
	b.roof_tex = "Roof_Tile_03"
	b.remap = b.floor_remap(1)
	b.fence(-4.9, -4.9, 4.9, 4.9)
	var m := 1.0 if b.rng.randf() < 0.5 else -1.0
	# пшеница — сзади, напротив хижины
	var gold := {"tint": Color(1.32, 1.08, 0.46)}
	for j in 3:
		for i in 5:
			var q := Vector3(m * (-4.0 + i * 1.3 + (0.35 if j % 2 else 0.0)), 0, -4.35 + j * 0.95)
			b.parts.append(["SM_Env_Grass_0%d" % (2 + (i + j) % 2), b.base * Transform3D(Basis(Vector3.UP, b.rng.randf() * TAU).scaled(Vector3(0.75, 1.05, 0.75)), q), gold])
	# грядки поперёк поля (вдоль X), шаг 0,93 — работники как раз между рядами
	var green := {"tint": Color(0.8, 1.0, 0.6)}
	var lens := [9.61, 8.75, 9.17]
	var mins := [-0.49, -0.23, -0.52]
	for i in 5:
		var k := 1 + i % 2               # отдельные кусты (первый ряд Synty — сплошная гряда-изгородь)
		var sl: float = 6.0 / (lens[k] as float)
		var z := -1.67 + i * 0.933
		b.parts.append(["SM_Env_Crop_Rows_0%d" % (1 + k), b.base * Transform3D(Basis(Vector3.UP, PI / 2).scaled_local(Vector3(0.72, 0.62, sl)), Vector3(-3.0 - (mins[k] as float) * sl, 0, z)), green])
	# хижина работников (1×1 модуль) с козырьком и сеном
	var hx := 3.35 * m
	var hz := -3.35
	_box(b, hx, hz, 1, 1, [{0: ["SM_Bld_Wall_Door_04"], 1: ["SM_Bld_Wall_Window_06"], 3: ["SM_Bld_Wall_Window_06"]}], {"trim": "SM_Bld_Trim_01"})
	_leaf(b, hx, hz, 1, 1, 0, "SM_Bld_Door_03")
	var r := _gable2(b, hx - 1.25, hx + 1.25, hz - 1.25, hz + 1.25, FL, 1.8, true)
	b.add("SM_Bld_Roof_Topper_01", Vector3(hx, r - 0.04, hz + 1.15), 0.0)
	b.add("SM_Prop_Overhang_02", Vector3(hx - 0.6, 2.5, hz + 1.37), 0.0)
	b.add("SM_Prop_Straw_Bundle_01", Vector3(hx - 1.6 * m, 0, hz + 0.9), 0.3)
	b.add("SM_Prop_Basket_Backpack_01", Vector3(hx + 0.9, 0, hz + 1.65), 0.4)
	# у хижины — мешки и корзины с урожаем
	b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(3.8 * m, 0, -0.9), 0.6, 0.9)
	b.add("SM_Prop_Basket_Set_01", Vector3(3.85 * m, 0, 0.7), 0.3, 0.7)
	b.add("SM_Prop_Basket_Set_01_Insert_01", Vector3(3.85 * m, 0, 0.7), 0.3, 0.7)
	# у работников — корзины между рядами
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(-1.7, 0, -1.2), 0.0, 0.75)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(2.0, 0, 1.6), 0.0, 0.75)
	# с другого края — коса у изгороди и сноп
	b.add("SM_Prop_Scythe_01", Vector3(-4.55 * m, 0.75, 1.6), 0.2)
	b.add("SM_Prop_Straw_Bundle_01", Vector3(-4.4 * m, 0, 0.0), 0.0)
	# спереди: стога, колодец, плуг, серп
	b.add("SM_Prop_Straw_Stack_04", Vector3(-3.5 * m, 0, 3.4), 0.5, 0.5)
	b.add("SM_Prop_Straw_Stack_01", Vector3(-2.1 * m, 0, 3.95), 1.0, 0.7)
	b.add("SM_Prop_Well_01", Vector3(3.7 * m, 0, 3.4), PI / 2, 0.62)
	b.add("SM_Prop_Plough_01", Vector3(-0.6 * m, 0, 3.7), 1.4)
	b.add("SM_Prop_Sickle_01", Vector3(0.6, 0.05, 2.75), 0.8)
	b.add("SM_Prop_Sack_0%d" % (3 + b.rng.randi() % 3), Vector3(1.6 * m, 0, 3.1), 0.6, 0.9)
	b.smoke.clear()
	b.door = Vector3(0, 0, 5.3)


## Оливковая роща: серебристые оливы ровными рядами в шахматном порядке (как сажали римляне), под деревом,
## где работает сборщик (−1,6; 1,6), — полотно для сбора, лестница и корзины; маслодавильня под черепичным
## навесом (жёрнов в чаше), амфоры масла
static func _grove(b: Bp) -> void:
	b.paint(9, false)
	b.roof_tex = "Roof_Tile_01"
	b.remap = b.floor_remap(1)
	b.fence(-4.9, -4.9, 4.9, 4.9)
	var spots := [Vector3(-3.2, 0, -3.2), Vector3(0.0, 0, -3.2), Vector3(3.2, 0, -3.2), Vector3(-1.6, 0, 0.0),
		Vector3(1.6, 0, 0.0), Vector3(-3.2, 0, 3.2), Vector3(0.0, 0, 3.2)]
	for p: Vector3 in spots:
		var k := b.rng.randf_range(0.37, 0.42)
		_tree(b, "SM_Env_Tree_0%d" % (3 + b.rng.randi() % 2), p, Vector3(k, k * 0.82, k), Color(0.82, 0.92, 0.95))
	# сборщик: полотно под деревом, лестница к дереву, корзины с оливками
	b.parts.append(["SM_Prop_Banner_Roof_01", b.base * Transform3D(Basis(Vector3.UP, 0.3), Vector3(-1.6, 0.06, 0.35)) * Transform3D(Basis.from_scale(Vector3(0.85, 0.08, 0.85)), Vector3(-1.1, 0, -1.1)), CLOTH])
	b.add_xf("SM_Prop_Ladder_01", Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(-1.75, 0, 1.05)))
	b.add("SM_Prop_Basket_Set_04", Vector3(-0.8, 0, 1.85), 0.5, 0.75)
	b.add("SM_Prop_Basket_Set_04_Insert_01", Vector3(-0.8, 0, 1.85), 0.5, 0.75)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(-2.5, 0, 1.9), 0.0, 0.75)
	# маслодавильня: жёрнов в каменной чаше под навесом на столбах
	_shed(b, 2.2, 4.7, 4.4, 2.1, 2.3, "SM_Bld_Trellis_Pillar_01", 0.9)
	b.add("SM_Prop_Bowl_01", Vector3(3.45, 0, 3.2), 0.0, 1.2)
	b.add("SM_Prop_Grinding_Wheel_01", Vector3(3.45, 0.3, 3.2), 0.6, 0.85)
	b.add("SM_Prop_Vase_Pile_02", Vector3(-1.6, 0, 3.75), PI / 2, 0.75)
	b.add("SM_Prop_Jar_01", Vector3(4.55, 0, 2.0), 0.0, 0.75)
	b.add("SM_Prop_Jar_01", Vector3(2.0, 0, 2.15), 0.0, 0.7)
	b.add("SM_Prop_Basket_Set_01", Vector3(-4.2, 0, 1.6), 1.7, 0.7)
	b.add("SM_Prop_Basket_Set_01_Insert_01", Vector3(-4.2, 0, 1.6), 1.7, 0.7)
	b.add("SM_Env_Grass_0%d" % (1 + b.rng.randi() % 3), Vector3(1.8, 0, 1.6), 0.0, 0.8)
	b.door = Vector3(0, 0, 5.3)


## Виноградник: ряды лоз на столбиках с жердью (вдоль Z; между рядами работает виноградарь (−1,5; −2,9)),
## спереди — давильня (большая чаша), корзины винограда, амфоры, Вакх под виноградной аркой
static func _vineyard(b: Bp) -> void:
	b.fence(-4.9, -4.9, 4.9, 4.9)
	var rows := [-3.85, -1.95, 0.05]
	for ri in rows.size():
		var z: float = rows[ri]
		for j in 3:
			b.add("SM_Env_Vine_0%d" % (1 + (j + ri) % 2 * 1), Vector3(-3.0 + j * 2.95, 0, z), (PI if (j + ri) % 2 else 0.0), 0.92)
		for x: float in [-4.55, 4.45]:
			b.add("SM_Bld_Trellis_Pillar_01", Vector3(x, 0, z), 0.0, 0.48)
		b.add_xf("SM_Prop_Beam_01", Transform3D(Basis.IDENTITY.scaled_local(Vector3(3.6, 0.7, 0.7)), Vector3(-4.55, 1.42, z)))
	# давильня: большая чаша с виноградом, корзины, амфоры
	b.add("SM_Prop_Bowl_02", Vector3(2.9, 0, 3.0), 0.0, 1.5)
	b.add("SM_Prop_Basket_Insert_0%d" % (1 + b.rng.randi() % 4), Vector3(2.9, 0.18, 3.0), 0.0, 1.25)
	b.add("SM_Prop_Basket_Set_06", Vector3(1.4, 0, 2.2), 0.3, 0.75)
	b.add("SM_Prop_Basket_Set_06_Insert_01", Vector3(1.4, 0, 2.2), 0.3, 0.75)
	b.add("SM_Prop_Basket_0%d" % (1 + b.rng.randi() % 5), Vector3(-1.05, 0, -2.2), 0.0, 0.75)
	b.add("SM_Prop_Vase_Pile_04", Vector3(4.1, 0, 3.4), PI / 2, 0.65)
	b.add("SM_Prop_Jug_0%d" % (1 + b.rng.randi() % 4), Vector3(2.1, 0, 3.9), 0.0, 0.9)
	# Вакх на постаменте под виноградной аркой
	for c: Vector3 in [Vector3(-3.8, 0, 2.4), Vector3(-1.6, 0, 2.4), Vector3(-3.8, 0, 4.4), Vector3(-1.6, 0, 4.4)]:
		b.add("SM_Bld_Trellis_Pillar_01", c, 0.0, 0.78)
	b.add_xf("SM_Bld_Trellis_Roof_01", Transform3D(Basis.IDENTITY.scaled(Vector3(0.95, 1, 0.85)), Vector3(-1.45, 2.44, 2.3)))
	b.add_xf("SM_Env_Vine_0%d" % (1 + b.rng.randi() % 2), Transform3D(Basis(Vector3.RIGHT, -PI / 2).scaled(Vector3(0.75, 1, 1)), Vector3(-2.7, 2.72, 4.3)))
	_statue(b, Vector3(-2.7, 0, 3.4), 0.0, 0.7)
	b.add("SM_Env_Flowers_0%d" % (1 + b.rng.randi() % 5), Vector3(-0.6, 0, 4.2), 0.0, 1.3)
	b.door = Vector3(0, 0, 5.3)


# =====================================================================
#   бани и термы
# =====================================================================

## Бани квартала: голубой корпус с белыми карнизами, на плоской крыше — купол-парилка (из купола — пар).
## Слева — бассейн со ступенями и львиной головой-фонтаном, справа — вход под черепичным навесом на колонках,
## к нему от улицы ведёт мраморная дорожка; полотенца, амфоры, пальма
static func _balnea(b: Bp) -> void:
	b.paint(4, false)
	b.ground_style = "plain"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_01"
	b.remap = b.floor_remap(1)
	var white := _skin(b, "Stucco_White_01", WHITE)
	var cz := -2.5
	_box(b, 0, cz, 3, 1, [{0: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Window_06", "SM_Bld_Wall_Door_Double_01"], 1: ["SM_Bld_Wall_Window_06"],
		2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_06"]}], {"trim": "SM_Bld_Trim_04", "trim_skin": white})
	_leaf(b, 0, cz, 3, 1, 2, "SM_Bld_Door_04", 0.1)
	var fz := cz + 1.25
	# плоская крыша с белым парапетом и куполом-парилкой
	for i in 3:
		b.add("SM_Bld_Roof_Base_Flat_02", Vector3(-3.75 + i * M, FL - 0.68, fz), 0.0)
	b.remap = white
	for side in 4:
		for i in (3 if side % 2 == 0 else 1):
			b.on_wall("SM_Bld_Wall_Balcony_06", 0, cz, 3, 1, side, i, FL, 0.0, true)
	b.remap = b.floor_remap(1)
	b.add("SM_Prop_Pergola_01", Vector3(0, FL + 0.05, cz), 0.0, 0.4)
	b.smoke.clear()
	b.smoke.append(b.base * Vector3(0, FL + 2.7, cz))
	b.add("SM_Prop_Vase_0%d" % (1 + b.rng.randi() % 6), Vector3(-3.3, FL, cz + 0.6), 0.0, 0.7)
	b.add("SM_Prop_FlowerPot_Fancy_01", Vector3(3.3, FL + 0.34, cz + 0.6), 0.0, 0.6)
	# бассейн перед двумя левыми пролётами, над ним — львиная голова под деревянным козырьком
	_pool(b, -3.75, 1.25, -0.55, 1.95)
	b.add("SM_Prop_Marble_LionHead_01", Vector3(-1.25, 1.15, fz + 0.12), 0.0, 0.7)
	b.add("SM_Prop_Fountain_03", Vector3(-1.25, 0.55, fz + 0.12), 0.0, 0.9)
	b.add("SM_Prop_Overhang_02", Vector3(-1.25, 2.5, fz + 0.1), 0.0)
	b.add("SM_Env_Lillies_0%d" % (1 + b.rng.randi() % 2), Vector3(-3.0, 0.13, 0.6), 0.0, 0.6)
	b.add("SM_Prop_Rug_Folded_0%d" % (1 + b.rng.randi() % 2), Vector3(-3.85, 0.22, 1.0), PI / 2, 0.7)
	b.add("SM_Prop_Rug_Folded_03", Vector3(0.2, 0.22, 2.0), 0.0, 0.6)
	# вход: мраморная дорожка, черепичный навес на колонках, фонарь, амфоры, скамья у стены
	_marble(b, Vector3(2.75, 0, 0.6), Vector3(2.0, 0.05, 3.7))
	_shed(b, 1.75, 3.95, 2.35, fz, 2.5, "SM_Bld_Pillar_06", 0.6, false, 0.82)
	b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(3.95, 0, 2.35), b.rng.randf() * TAU, 0.8)
	_wall_lamp(b, Vector3(1.6, 2.2, fz + 0.08))
	b.add("SM_Prop_Jug_06", Vector3(3.55, 0, -0.75), 0.0, 0.9)
	b.add("SM_Prop_Vase_0%d" % (1 + b.rng.randi() % 6), Vector3(3.55, 0, 1.6), 0.0, 0.8)
	b.add("SM_Prop_Basket_Set_02", Vector3(4.45, 0, -0.4), 0.0, 0.55)
	# по краям: колонна с плющом и жаровня у бассейна, пальма у входа
	b.add("SM_Bld_Pillar_01", Vector3(-4.15, 0, 2.3), 0.0, 0.8)
	b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(-4.15, 0, 2.3), b.rng.randf() * TAU, 0.8)
	b.brazier(Vector3(-4.2, 0, 0.9))
	b.add("SM_Env_Tree_Palm_0%d" % (1 + b.rng.randi() % 3), Vector3(4.4, 0, -1.7), b.rng.randf() * TAU, 0.33)
	b.door = Vector3(2.6, 0, 3.0)


## Термы: высокий зал — внизу помпейский красный, вверху белый, с нишами и окнами; на крыше — купола (из большого
## пар). Перед залом — два бассейна-натацио, между ними мраморная дорожка к входу; по сторонам — крытые
## колоннады со статуями в нишах, пальмы, скамьи
static func _baths(b: Bp) -> void:
	b.paint(6, false)
	b.tint = Color(1.0, 0.95, 0.86)
	b.ground_style = "pattern"
	b.upper_style = "plain"
	b.roof_tex = "Roof_Tile_01"
	b.remap = b.floor_remap(1)
	var red := _skin(b, "Stucco_Red_01", Color(1.0, 0.86, 0.8))
	var white := _skin(b, "Stucco_White_01", WHITE)
	var cz := -4.15
	_box(b, 0, cz, 5, 1, [
		{0: ["SM_Bld_Wall_Window_06", "SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Window_06"], 1: ["SM_Bld_Wall_Window_06"],
			2: ["SM_Bld_Wall_01", "SM_Bld_Wall_Window_06", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_06", "SM_Bld_Wall_01"], 3: ["SM_Bld_Wall_Window_06"]},
		{0: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_05", "SM_Bld_Wall_Window_01"], 1: ["SM_Bld_Wall_Window_01"],
			2: ["SM_Bld_Wall_Window_01", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_01", "SM_Bld_Wall_01", "SM_Bld_Wall_Window_01"], 3: ["SM_Bld_Wall_Window_01"]}],
		{"trim": "SM_Bld_Trim_02", "plain": [2], "skin": [red, white], "trim_skin": white, "dark_front": 0.65})
	var fz := cz + 1.25
	for i: int in [1, 3]:
		var a := b.wall_at(0, cz, 5, 1, 0, i + 0.5, 0.22, -0.32)
		b.add("SM_Prop_Statue_0%d" % (1 + (i + b.rng.randi()) % 7), a[0], a[1], NICHE)
	# крыша: плоская с парапетом, по центру — купол
	for i in 5:
		b.add("SM_Bld_Roof_Base_Flat_02", Vector3(-6.25 + i * M, 2 * FL - 0.68, fz), 0.0)
	b.remap = white
	for side in 4:
		for i in (5 if side % 2 == 0 else 1):
			b.on_wall("SM_Bld_Wall_Balcony_05", 0, cz, 5, 1, side, i, 2 * FL, 0.0, true)
	b.remap = b.floor_remap(1)
	b.add("SM_Prop_Pergola_01", Vector3(0, 2 * FL + 0.05, cz), 0.0, 0.48)
	b.add("SM_Prop_Pergola_01", Vector3(-3.75, 2 * FL + 0.05, cz), 0.0, 0.3)
	b.add("SM_Prop_Pergola_01", Vector3(3.75, 2 * FL + 0.05, cz), 0.0, 0.3)
	b.smoke.clear()
	b.smoke.append(b.base * Vector3(0, 2 * FL + 3.1, cz))
	for x: float in [-5.6, 5.6]:
		b.add("SM_Prop_Vase_0%d" % (1 + b.rng.randi() % 6), Vector3(x, 2 * FL, fz - 0.5), 0.0, 0.8)
	b.wall_banner(0, cz, 5, 1, 0.5, 2 * FL - 0.35)
	b.wall_banner(0, cz, 5, 1, 4.5, 2 * FL - 0.35)
	_wall_lamp(b, Vector3(-1.4, 2.4, fz + 0.06))
	_wall_lamp(b, Vector3(1.4, 2.4, fz + 0.06))
	# два бассейна по 1×2 модуля и мраморная дорожка между ними к двери
	var pz0 := fz + 0.8
	_pool(b, -3.75, -1.25, pz0, pz0 + 5.0)
	_pool(b, 1.25, 3.75, pz0, pz0 + 5.0)
	_marble(b, Vector3(0, 0, (fz + pz0 + 5.3) / 2.0), Vector3(2.5, 0.06, pz0 + 5.3 - fz))
	b.add("SM_Prop_Fountain_01", Vector3(-2.5, 0.0, pz0 + 0.25), 0.0, 0.9)
	b.add("SM_Prop_Fountain_01", Vector3(2.5, 0.0, pz0 + 0.25), 0.0, 0.9)
	b.add("SM_Env_Lillies_0%d" % (1 + b.rng.randi() % 3), Vector3(-2.5, 0.13, pz0 + 3.6), 0.0, 0.55)
	b.add("SM_Prop_Rug_Folded_03", Vector3(2.9, 0.22, pz0 + 5.25), 0.0, 0.6)
	# колоннады по сторонам бассейнов (кровля к наружной стороне)
	for side: float in [-1.0, 1.0]:
		var keep := b.base
		b.base = keep * Transform3D(Basis(Vector3.UP, -side * PI / 2), Vector3(side * 6.5, 0, pz0 + 2.5))
		_stoa(b, 2.5, 1.55, "SM_Bld_Pillar_02", ["SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Window_06"])
		b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(-1.25, 0.22, -0.32), 0.0, 0.78)
		b.add("SM_Prop_Seat_Bench_03", Vector3(1.25, 0, 0.5), 0.0, 0.8)
		b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(0, 0, 1.55), b.rng.randf() * TAU, 0.85)
		b.base = keep
	# статуи у бассейнов, жаровни у начала дорожки, пальмы, корзины
	_statue(b, Vector3(-4.6, 0, pz0 + 5.4), 0.0, 0.8)
	_statue(b, Vector3(4.6, 0, pz0 + 5.4), 0.0, 0.8)
	b.brazier(Vector3(-1.6, 0, pz0 + 5.45))
	b.brazier(Vector3(1.6, 0, pz0 + 5.45))
	b.add("SM_Env_Tree_Palm_0%d" % (1 + b.rng.randi() % 3), Vector3(-6.5, 0, fz - 0.5), b.rng.randf() * TAU, 0.45)
	b.add("SM_Env_Tree_Palm_0%d" % (1 + b.rng.randi() % 3), Vector3(6.5, 0, fz - 0.4), b.rng.randf() * TAU, 0.42)
	b.add("SM_Prop_Basket_Set_02", Vector3(4.6, 0, fz + 0.4), 0.0, 0.6)
	b.add("SM_Prop_Rug_Folded_03", Vector3(-4.6, 0, fz + 0.4), 0.0, 0.7)
	b.door = Vector3(0, 0, pz0 + 6.0)


# =====================================================================
#   одеон и театр
# =====================================================================

## Полукруг ступеней-трибун (четыре клина амфитеатра) с центром c: s — масштаб, sy — крутизна; по краям — торцы
static func _cavea(b: Bp, c: Vector3, s: float, sy: float) -> void:
	for i in 4:
		b.add_xf("SM_Bld_Amphitheatre_01", Transform3D(Basis(Vector3.UP, PI / 2 - i * PI / 4).scaled(Vector3(s, s * sy, s)), c))
	b.add_xf("SM_Bld_Amphitheatre_End_01", Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3(s, s * sy, s)), c))
	# правый торец — тот же, повёрнутый на другой край (без зеркала: пул деталей не выворачивает грани)
	b.add_xf("SM_Bld_Amphitheatre_End_01", Transform3D(Basis(Vector3.UP, -PI / 2).scaled(Vector3(s, s * sy, s)), c + Vector3(0, 0, 2.5 * s)))


## Наружная стена трибун — глухая аркада из каменных арок (как у театра Марцелла): 8 арок по 22,5°,
## пилястры на стыках, карниз поверху, плющ на двух арках
static func _cavea_arcade(b: Bp, c: Vector3, s: float, sy: float) -> void:
	var r := 22.5 * s + 0.12
	var h := 4.58 * s * sy
	var half := r * tan(PI / 16.0)
	b.remap = TRAVERTINE
	for i in 8:
		var a := PI + (i + 0.5) * PI / 8.0
		var o := Vector3(cos(a), 0, sin(a))
		var t := Vector3(sin(a), 0, -cos(a))
		var bas := Basis(t, Vector3.UP, o)
		var mid := c + o * r
		b.add_xf("SM_Bld_Wall_Door_Large_01", Transform3D(bas * Basis.from_scale(Vector3(half * 2.0 / M, h / 3.0, 1.0)), mid - t * half), true)
		b.add_xf("SM_Bld_Trim_Large_Single_01", Transform3D(bas * Basis.from_scale(Vector3(half * 2.0 / M, 0.42, 0.75)), mid - t * half + Vector3(0, h, 0)))
		if i == 2 or i == 5:
			b.add_xf("SM_Env_Ivy_Flowers_0%d" % (1 + b.rng.randi() % 5), Transform3D(bas, mid + o * 0.33 + Vector3(0, h * 0.5, 0)))
	for i in 9:
		var a := PI + i * PI / 8.0
		b.add_xf("SM_Bld_Wall_Large_Pillar_01", Transform3D(Basis.from_scale(Vector3(0.6, h / 4.55, 0.6)), c + Vector3(cos(a), 0, sin(a)) * (r / cos(PI / 16.0))), true)
	b.remap = b.floor_remap(1)


## Одеон: малый театр для музыки — крутые трибуны в каменной аркаде, мраморная сцена высотой 0,5 (музыкант у z = 3,4),
## за ним — лёгкая колоннада с гирляндами, лира на подставке, музы на постаментах, два светлых паруса над трибунами
static func _odeon(b: Bp) -> void:
	b.paint(6, false)
	b.remap = b.floor_remap(1)
	var cz := 1.5
	var s := 0.25
	var c := Vector3(0, 0.0, cz)
	_cavea(b, c, s, 1.55)
	_cavea_arcade(b, c, s, 1.55)
	_marble(b, Vector3(0, 0, cz - 0.6), Vector3(2.4, 0.04, 1.2))
	# сцена
	_marble(b, Vector3(0, 0, 3.45), Vector3(9.0, 0.5, 2.3))
	# расписной фриз по фасаду сцены (к зрителям)
	for x: float in [-2.55, 0.0, 2.55]:
		b.add("SM_Prop_Mural_0%d" % (3 + b.rng.randi() % 2), Vector3(x, 0.26, 2.29), PI, 1.0)
	# колоннада сзади сцены (за музыкантом), гирлянды, знамя
	for x: float in [-3.75, -1.25, 1.25, 3.75]:
		b.add("SM_Bld_Pillar_06", Vector3(x, 0.5, 4.3), 0.0, 0.78)
	for x: float in [-3.75, 3.75]:
		b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(x, 0.5, 4.3), b.rng.randf() * TAU, 0.78)
	_pot(b, Vector3(-4.2, 0.5, 4.2), 0.5)
	_pot(b, Vector3(4.2, 0.5, 4.2), 0.5)
	Catalog._trim_run(b, Vector3(-4.2, 0.5 + 2.34 + 0.48, 4.03), Vector3(1, 0, 0), 8.4)
	_trim_back(b, Vector3(-4.2, 0.5 + 2.34 + 0.48, 4.03), 8.4)
	for i in 3:
		b.add("SM_Prop_Drapery_0%d" % (1 + i), Vector3(-2.5 + i * M, 2.75, 4.0), PI)
	b.add("SM_Prop_Banner_0%d_%s" % [1 + b.rng.randi() % 3, ["A", "C", "H"][b.rng.randi() % 3]], Vector3(0, 2.7, 4.3), PI, 0.6)
	# лира на подставке, стул музыканта, жаровни
	b.add("SM_Prop_Plinth_02", Vector3(1.0, 0.5, 3.3), 0.0, 0.85)
	b.add("SM_Prop_Lyre_01", Vector3(1.0, 1.45, 3.3), PI, 0.9)
	b.add("SM_Prop_Seat_Chair_01", Vector3(-1.0, 0.5, 3.5), PI, 0.9)
	b.brazier(Vector3(-4.0, 0.5, 2.7))
	b.brazier(Vector3(4.0, 0.5, 2.7))
	_lamp_post(b, Vector3(-5.0, 0, 4.0), 0.0)
	_lamp_post(b, Vector3(5.0, 0, 4.0), PI)
	# музы на постаментах у торцов трибун, кипарисы
	_statue(b, Vector3(-5.3, 0, 2.65), 0.0, 0.8)
	_statue(b, Vector3(5.3, 0, 2.65), 0.0, 0.8)
	_cypress(b, Vector3(-5.6, 0, -2.4), 0.48)
	_cypress(b, Vector3(5.6, 0, -2.4), 0.48)
	# мачты на краю трибун и два паруса велария между ними
	var r := 22.5 * s
	var rim := 4.58 * s * 1.55
	for k in 3:
		var a := PI + PI / 4 + k * PI / 4
		var p := Vector3(cos(a) * (r - 0.1), rim - 0.05, cz + sin(a) * (r - 0.1))
		b.add("SM_Prop_Pole_02", p, 0.0, 0.8)
		b.add("SM_Prop_Banner_05", p + Vector3(0, 2.4, 0), -a, 0.8)
	_sail(b, c, PI + 3.0 * PI / 8, r - 1.2, rim + 1.5, 3.8, 2.1)
	_sail(b, c, PI + 5.0 * PI / 8, r - 1.2, rim + 1.5, 3.8, 2.1)
	b.door = Vector3(0, 0, 5.3)


## Театр: широкие крутые трибуны в каменной аркаде, орхестра, мраморная сцена высотой 0,6 (актёры у z = 5,6…5,8),
## за ними — скена: мраморная стена с арками и нишами со статуями, перед ней два яруса колонн; к улице стена
## смотрит фасадом с факелами, знамёнами и табличкой. Над трибунами — три светлых паруса на мачтах
static func _theatre(b: Bp) -> void:
	b.paint(6, false)
	b.ground_style = "pattern"
	b.remap = b.floor_remap(1)
	var cz := 3.9
	var s := 0.34
	var c := Vector3(0, 0.0, cz)
	_cavea(b, c, s, 1.6)
	_cavea_arcade(b, c, s, 1.6)
	_marble(b, Vector3(0, 0, cz - 0.8), Vector3(3.2, 0.04, 1.6))
	_statue(b, Vector3(0, 0.04, cz - 0.95), 0.0, 0.62)
	# сцена (доходит до задней стены скены)
	_marble(b, Vector3(0, 0, 5.725), Vector3(13.0, 0.6, 3.45))
	# расписной фриз по фасаду сцены (к зрителям)
	for x: float in [-5.1, -2.55, 0.0, 2.55, 5.1]:
		b.add_xf("SM_Prop_Mural_0%d" % (3 + b.rng.randi() % 2), Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(1, 1.15, 1)), Vector3(x, 0.3, 3.99)))
	# стена скены: к зрителям — ниши со статуями по краям, арки, большие двери посередине
	var y1 := 0.6
	var walls := ["SM_Bld_Wall_Alcove_01", "SM_Bld_Wall_Door_Large_01", "SM_Bld_Wall_Door_Double_Large_01", "SM_Bld_Wall_Door_Large_01", "SM_Bld_Wall_Alcove_01"]
	b.remap = MARBLE
	for i in 5:
		b.add_xf(walls[i], Transform3D(Basis(Vector3.UP, PI).scaled(Vector3(1, 0.85, 1)), Vector3(-5.0 + i * M + 1.25, y1, 7.1)), true)
	b.remap = b.floor_remap(1)
	for x: float in [-5.0, 5.0]:
		b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(x, y1 + 0.19, 7.28), PI, 0.5)
	# скена: нижний ярус колонн перед стеной, антаблемент, верхний ярус, статуи, занавеси
	var xs := [-6.25, -3.75, -1.25, 1.25, 3.75, 6.25]
	for x: float in xs:
		b.add("SM_Bld_Pillar_04", Vector3(x, y1, 6.7), 0.0, 0.85)
	for x: float in [-6.25, 6.25]:
		b.add("SM_Env_Ivy_Pillar_Flowers_0%d" % (1 + b.rng.randi() % 2), Vector3(x, y1, 6.7), b.rng.randf() * TAU, 0.85)
	# статуи на торцах трибун
	for x: float in [-6.9, 6.9]:
		b.add("SM_Prop_Statue_0%d" % (1 + b.rng.randi() % 7), Vector3(x, 5.18 * s * 1.6 - 0.75, cz - 0.3), 0.0, 0.55)
	var y2 := y1 + 2.55
	Catalog._trim_run(b, Vector3(-6.7, y2 + 0.48, 6.43), Vector3(1, 0, 0), 13.4)
	_trim_back(b, Vector3(-6.7, y2 + 0.48, 6.43), 13.4)
	for x: float in xs:
		b.add("SM_Bld_Pillar_06", Vector3(x, y2 + 0.96, 6.7), 0.0, 0.62)
	var y3 := y2 + 0.96 + 1.86
	Catalog._trim_run(b, Vector3(-6.7, y3 + 0.48, 6.43), Vector3(1, 0, 0), 13.4)
	_trim_back(b, Vector3(-6.7, y3 + 0.48, 6.43), 13.4)
	for i in 5:
		var x: float = xs[i] + 1.25
		if i != 2:
			b.add("SM_Prop_Statue_0%d" % (1 + (i + b.rng.randi()) % 7), Vector3(x, y2 + 0.96, 6.75), PI, 0.55)
		b.add("SM_Prop_Drapery_0%d" % (1 + i % 3), Vector3(x, y2 - 0.15, 6.42), PI)
	b.add("SM_Prop_Banner_04_%s" % ["A", "B", "C", "D"][b.rng.randi() % 4], Vector3(0, y3 - 0.1, 6.45), PI, 0.5)
	b.add("SM_Bld_Roof_Topper_05", Vector3(-6.25, y3 + 0.7, 6.6), 0.0, 1.2)
	b.add("SM_Bld_Roof_Topper_05", Vector3(6.25, y3 + 0.7, 6.6), 0.0, 1.2)
	b.brazier(Vector3(-5.9, y1, 4.6), true)
	b.brazier(Vector3(5.9, y1, 4.6), true)
	# на сцене: ковёр, лира
	b.add("SM_Prop_Rug_0%d" % (1 + b.rng.randi() % 3), Vector3(0, y1 + 0.01, 5.6), PI / 2, 1.0)
	b.add("SM_Prop_Lyre_01", Vector3(3.3, y1 + 0.3, 6.1), PI, 0.8)
	# улица: фасад скены — факелы у боковых арок, длинные знамёна на нишах, табличка над главной дверью
	for x: float in [-2.5, 2.5]:
		for dx: float in [-1.05, 1.05]:
			var p := Vector3(x + dx, y1 + 1.75, 7.52)
			b.add("SM_Prop_Torch_01", p, 0.0)
			b.light(p + Vector3(0, 0.25, 0.1))
	for x: float in [-5.0, 5.0]:
		b.add("SM_Prop_Banner_03_%s" % ["A", "C", "E", "G"][b.rng.randi() % 4], Vector3(x, y1 + 2.45, 7.66), 0.0, 0.85)
	b.add("SM_Prop_Symbol_05", Vector3(0, y1 + 2.12, 7.45), 0.0, 0.6)
	# мачты по краю трибун и три паруса велария
	var r := 22.5 * s
	var rim := 4.58 * s * 1.6
	for k in 4:
		var a := PI + k * PI / 3
		var p := Vector3(cos(a) * (r - 0.1), rim - 0.05, cz + sin(a) * (r - 0.1))
		b.add("SM_Prop_Pole_01", p, 0.0, 1.0)
		b.add("SM_Prop_Banner_05", p + Vector3(0, 3.0, 0), -a, 0.9)
	for k in 3:
		_sail(b, c, PI + (k + 0.5) * PI / 3, r - 1.5, rim + 1.75, 5.4, 2.7)
	# кипарисы по углам
	_cypress(b, Vector3(-7.4, 0, 6.6), 0.5)
	_cypress(b, Vector3(7.4, 0, 6.6), 0.5)
	b.door = Vector3(0, 0, 8.4)
