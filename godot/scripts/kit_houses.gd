class_name KitHouses
extends RefCounted
## Дома из своего набора деталей (владелец 11.11: «переделал бы все дома на новые»). Облик и этажность → готовый
## дом из Blender (KitLib: "K:pleb_<облик>_<этажи>/…"), створки ставен и дверей — общие детали на своих петлях.
## Чертёж — в единицах Bp до Catalog._scale (×ARCH), поэтому всё делится на ARCH: после уменьшения — метры как в Blender.
## Старые дома в сохранениях (legacy: стоят на старом, более узком следе) — та же модель, ужатая по своему следу,
## чтобы не налезала на соседей.

const IDS := {"house_pleb": ["pleb", 5, 3], "house_artisan": ["artisan", 5, 3], "house_patrician": ["patrician", 6, 2]}   # тип → [класс, обликов, этажей]
static var ON := true                              # выключатель (false — прежние дома из Synty; test_cards сравнивает)

static var _old := {}


## Лавки (у каждой — один облик) и прилавки рынка
const SHOPS := ["butcher", "bakery", "cobbler", "dyer", "tailor", "potter", "oilshop", "lamps", "wineshop", "perfumer",
	"jeweler", "weaver", "barber", "medic", "thermopolium", "taberna", "fullonica", "mansio", "scriptorium", "herbalist", "catshop"]
const STALLS := ["stall_fruit", "stall_veg", "stall_fish"]
## Общественные здания (свой облик у каждого: "civ_<тип>"); у школы скамьи и кресло учителя — детали Synty (Spectacle)
## Большие термы — свои: Synty-термы в городе из своих домов дают +10 новых вызовов отрисовки (бюджет волны 5б, stage5b_owner)
const CIVIC := ["school", "library", "academy", "warehouse", "vigiles", "prefect", "balnea", "baths", "sculptor", "shelter", "thermae"]
## Памятники — свои, меньше прежних (владелец 12.11: «отказаться от супер огромных зданий»): "mon_<тип>"
## Храм, форум, пантеон, храм Венеры, маяк и лудус — снова Synty, но меньше (Catalog.SHRINK): свои вышли
## беднее (владелец 12.11: «новые большие здания выглядят ужасно… комбинируй наборы»); их модели остаются в наборе
const MONO := [
	# прогон 4: фонтан, нимфей, арка, огород, уличные артисты (у музыкантов лира и скамья, у игроков стулья — Synty)
	"fountain", "nymphaeum", "arch", "ogorod", "musicians", "dice", "puppets", "mimes"]


static func covers(type: String) -> bool:
	return ON and (IDS.has(type) or type in SHOPS or type in STALLS or type in CIVIC or type in MONO or type == "center")


static func id_for(type: String, tier: int, variant: int) -> String:
	if type in SHOPS:
		return "shop_" + type
	if type in STALLS:
		return type
	if type in CIVIC:
		return "civ_" + type
	if type in MONO:
		return "mon_" + type
	if type == "center":
		return "civ_center%d" % clampi(tier, 0, 7)     # почтовая станция растёт с уровнем города
	var e: Array = IDS[type]
	var v := posmod(variant, int(e[1]))
	var top := int(e[2])
	if type == "house_patrician" and v >= Defs.PAT_TOWN:
		top = 3                                  # городской домус (после перестройки) — до трёх этажей
	return "%s_%d_%d" % [e[0], v, clampi(tier, 1, top)]


## Построить дом в чертёж b. false — такого облика в наборе нет (тогда строится прежний)
static func build(b: Bp, type: String, tier: int, variant: int, legacy := false) -> bool:
	var id := id_for(type, tier, variant)
	var h := KitLib.house(id)
	if h.is_empty():
		return false
	var S := 1.0 / Catalog.ARCH
	var fp0: Array = (h["fp"] as Array)[0]
	var fp := Rect2(float(fp0[0]), float(fp0[1]), float(fp0[2]), float(fp0[3]))
	var sx := 1.0
	var sz := 1.0
	var off := Vector3.ZERO
	if legacy:
		var old := old_fp(type, variant)
		if old.size.x > 0.1:
			sx = old.size.x / fp.size.x
			sz = old.size.y / fp.size.y
			off = Vector3(old.position.x - fp.position.x * sx, 0, old.position.y - fp.position.y * sz)
	if not legacy and h.has("off"):
		off = _v(h["off"])                   # станция: ядро в Blender — посередине, в игре фасад — где у прежней
	var sq := Transform3D(Basis.from_scale(Vector3(sx, 1, sz)), off)       # в метрах (после ARCH)
	var base := Transform3D(Basis.from_scale(Vector3.ONE * S), Vector3.ZERO) * sq
	var shop := not type.begins_with("house_")
	for n: String in h["parts"]:
		# у общественного здания свой цвет штукатурки (из Blender), у дома — цвет из палитры игры
		var remap := {"tint": Color(String(h["tint"])) if h.has("tint") else b.tint} if n == "Walls" else {}
		# у лавки нутро в сумерках светится всегда (как прежние «#lit» лавок); у дома — когда в нём живут (Game._show)
		var nm := "K:%s/%s" % [id, n] + ("@lit" if shop and n == "Rooms" else "")
		b.parts.append([nm, base, remap])
	for pr: Array in h.get("props", []):
		# детали Synty (столы и стулья таверны — по ним Spectacle сажает гостей); масштаб — как у Synty в чертеже
		var pp := sq * Vector3(float(pr[1]), float(pr[2]), float(pr[3]))
		if String(pr[0]).begins_with("@"):
			_decor_group(b, String(pr[0]).substr(1), pp, float(pr[4]), float(pr[5]))
			continue
		var ps: Vector3 = Vector3(float(pr[5][0]), float(pr[5][1]), float(pr[5][2])) if pr[5] is Array else Vector3.ONE * float(pr[5])
		var rb := Basis(Vector3.UP, float(pr[4]))
		if pr.size() > 6 and pr[6] != null:
			rb = rb * Basis(Vector3.RIGHT, float(pr[6]))       # наклон (лира, прислонённая к скамье)
		var rm := _remap(b, pr[7]) if pr.size() > 7 and pr[7] is Dictionary else {}
		b.parts.append([String(pr[0]), Transform3D(rb * Basis.from_scale(ps), pp * S), rm])
	for j: Array in h.get("jets", []):
		b.jets.append([sq * Vector3(float(j[0]), float(j[1]), float(j[2])) * S, float(j[3]) * S, float(j[4])])
	for a: Array in h.get("actors", []):
		b.actor((sq * Vector3(float(a[0]), float(a[1]), float(a[2]))) * S, float(a[3]), String(a[4]), String(a[5]))
	b.kit_mov = []
	b.kit_sq = sq
	for m: Dictionary in h["mov"]:
		var xl := Transform3D(Basis(_v(m["x"]), _v(m["y"]), _v(m["z"])), _v(m["o"]))
		b.kit_mov.append([b.parts.size(), _v(m["o"]), _v(m["u"]), _v(m["nrm"]), int(m.get("side", 1)), float(m["open"]), String(m["kind"])])
		b.parts.append(["K:common/" + String(m["mesh"]), base * xl, {}])
	for l: Dictionary in h.get("lights", []):
		var lp := sq * _v(l["lamp"])
		if String(l.get("kind", "")) == "hang":
			b.light(lp * S)                  # светильник свой (в модели), здесь — только свет ночью
			continue
		# фонарик у двери (как у прежних домов: «#wall_lamp», у жилых ночью еле теплится); он в единицах Bp
		b.parts.append(["#wall_lamp", Transform3D(Basis.IDENTITY, lp * S), {}])
		b.light((lp + Vector3(0, -0.14, 0.3)) * S)
	b.door = (sq * _v(h["door"])) * S
	for sp: Array in h.get("smoke", []):
		b.smoke.append((sq * _v(sp)) * S)     # печь гончара во дворе
	b.kit_id = id
	var fr := Rect2(fp.position.x * sx + off.x, fp.position.y * sz + off.z, fp.size.x * sx, fp.size.y * sz)
	b.fp_override = [fr]
	b.kit_faces = _faces(h, sx, sz, off)
	# коробки для щелчка и «заслоняет ли»: стены, крыша над ними, низкий двор/сад, у домуса — портик
	var kb: Array = b.kit_bounds()
	var ht := float(h["ht"])
	var ridge := float(h.get("ridge", ht + 1.0))
	var x0 := float(kb[0])
	var x1 := float(kb[1])
	var z0 := float(kb[2])
	var z1 := float(kb[3])
	b.kit_boxes = [AABB(Vector3(x0, 0, z0), Vector3(x1 - x0, ht, z1 - z0)),
		AABB(Vector3(x0 - 0.2, ht - 0.15, z0 - 0.25), Vector3(x1 - x0 + 0.4, ridge - ht + 0.3, z1 - z0 + 0.5)),
		AABB(Vector3(fr.position.x, 0, fr.position.y), Vector3(fr.size.x, 1.0, fr.size.y))]
	if type == "house_patrician" and fr.end.y > z1 + 0.3:
		b.kit_boxes.append(AABB(Vector3(-1.1 * sx, 0, z1), Vector3(2.2 * sx, 2.5, fr.end.y - z1)))
	b.perch = []
	for p: Array in h.get("perch", []):
		b.perch.append(sq * Vector3(float(p[0]), float(p[1]), float(p[2])))
	return true


## Животные и вещицы при здании из своего набора (как CatExtra.PETS: кошки приюта и лавки, ослик, вещицы витрины);
## пусто — у постройки свой список в CatExtra/CatDecor2
static func pets(type: String) -> Array:
	if not covers(type):
		return []
	var h := KitLib.house(id_for(type, 0, 0))
	var out := []
	for e: Array in h.get("pets", []):
		var q := e.duplicate()
		q[1] = _v(e[1])
		out.append(q)
	return out


## Украшение Synty целиком (жаровня с огнём, кипарис, клумба, канделябр, лев…) — как в меню «Украшения»
## (владелец 12.11: «можно же было использовать старые из Synty, вообще можно всё комбинировать»): детали, свет, дым.
## pp — место в метрах, k — масштаб к обычному украшению
static func _decor_group(b: Bp, type: String, pp: Vector3, yaw: float, k: float) -> void:
	if not Defs.B.has(type):
		push_warning("KitHouses: нет украшения " + type)
		return
	var d := Catalog.make(type, 0, 0, int(Defs.B[type].get("color", 0)))
	var S := 1.0 / Catalog.ARCH
	var T := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * k), pp)
	var toB := Transform3D(Basis.from_scale(Vector3.ONE * S), Vector3.ZERO)
	for p in d.parts:
		b.parts.append([p[0], toB * T * (p[1] as Transform3D), p[2]])
	for l in d.lights:
		b.light(S * (T * (l as Vector3)))
	for sm in d.smoke:
		b.smoke.append(S * (T * (sm as Vector3)))


## Перекраска детали Synty из kit.json: {"tint": [r, g, b]}, {"rm": "MOSAIC"} (CatMonuments), {"skin": "Building_Marble_01"}
static func _remap(b: Bp, r: Dictionary) -> Dictionary:
	if r.has("tint"):
		var c: Array = r["tint"]
		return {"tint": Color(float(c[0]), float(c[1]), float(c[2]))}
	if r.has("skin"):
		return CatCivic._skin(b, String(r["skin"]))
	if r.has("rm"):
		match String(r["rm"]):
			"MOSAIC": return CatMonuments.MOSAIC
			"PAVING": return CatMonuments.PAVING
			"SAND": return CatMonuments.SAND
			"STONE_WALL": return CatMonuments.STONE_WALL
			"RED_WALL": return CatMonuments.RED_WALL
			"TRAV_BLOCKS": return CatMonuments.TRAV_BLOCKS
			"STONE_ARCH": return CatMonuments.STONE_ARCH
			"MARBLE_WALL": return CatMonuments.MARBLE_WALL
			"MARBLE_BLOCKS": return CatMonuments.MARBLE_BLOCKS
			"WARM_PAVING": return CatMonuments.WARM_PAVING
			"PORCH": return CatMonuments.PORCH
			"CAP_MARBLE": return CatMonuments.CAP_MARBLE
			"SWAG_RED": return CatMonuments.SWAG_RED
	return {}


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Стены для настенных украшений (WallDecor.faces) — в метрах, с учётом сжатия старого дома
static func _faces(h: Dictionary, sx: float, sz: float, off: Vector3) -> Array:
	var out := []
	for f: Dictionary in h.get("faces", []):
		var n := _v(f["n"])
		var a := _v(f["a"])
		var sc_n := absf(n.x) * sx + absf(n.z) * sz
		var sc_a := absf(a.x) * sx + absf(a.z) * sz
		var d := float(f["d"]) * sc_n + n.dot(off)
		var b0: Array = f["bound"]
		var bound := Rect2(float(b0[0]) * sc_a + a.dot(off), float(b0[1]), float(b0[2]) * sc_a, float(b0[3]))
		var blocks := []
		for r: Array in f["block"]:
			blocks.append(Rect2(float(r[0]) * sc_a + a.dot(off), float(r[1]), float(r[2]) * sc_a, float(r[3])))
		var opens := []
		for r: Array in f.get("open", []):
			opens.append(Rect2(float(r[0]) * sc_a + a.dot(off), float(r[1]), float(r[2]) * sc_a, float(r[3])))
		out.append({"n": n, "a": a, "d": d, "mods": [bound], "block": blocks, "bound": bound, "open": opens,
			"side": String(f.get("side", ""))})
	return out


## След прежнего дома (тех же типа и облика) — по нему ужимается дом из старого сохранения
static func old_fp(type: String, variant: int) -> Rect2:
	var key := "%s:%d" % [type, variant]
	if _old.has(key):
		return _old[key]
	var ob := Bp.new(hash(key))
	ob.paint(0)
	match type:
		"house_pleb": CatHouses._house_pleb(ob, 1, variant)
		"house_artisan": CatHouses._house_artisan(ob, 1, variant)
		"house_patrician":
			if variant >= Defs.PAT_TOWN:
				CatHouses._house_patrician_town(ob, 1, variant)
			else:
				CatHouses._house_patrician(ob, 1, variant)
	ob.base = Transform3D.IDENTITY
	Catalog._scale(ob, Catalog.ARCH)
	var r := Rect2()
	var first := true
	for q: Rect2 in ob.footprint():
		r = q if first else r.merge(q)
		first = false
	_old[key] = r
	return r
