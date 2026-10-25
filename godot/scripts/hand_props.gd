class_name HandProps
extends RefCounted
## Вещи в руках жителей (этап 4): лира у музыканта, бубен у танцовщицы, свиток у писца, серп в поле, корзина в роще,
## хлеб у пекаря, кувшин в таверне, кадильница у жреца, копьё и щит у стражи, бритва у цирюльника; покупки — домой
## (People.carry). Вещь — на кости кисти (BoneAttachment3D «HandProp»); как её держать — по позе движения: кисть
## в осях скелета на кадре t (LegionFighter._pose), вещь в этих осях стоит так, как задано (up — её ось вверх,
## fwd — куда смотрит лицом, off — сдвиг от кисти), и дальше ходит вместе с кистью. Без тени: мелочь, а вызовов вдвое меньше.
## Вещи — только вблизи камеры и не на «Низкой» (People._props_tick).

## mesh: модель Synty («SM_…»), Artisau («@Имя») или своя («#tympanum», «#razor»); h — высота (или длина) вещи в метрах
## скелета (житель — 1,8 м до уменьшения); anchor — чем вещь в кисти: center | top (ручка сверху: кувшин, корзина)
const DEF := {
	"lyre": {"mesh": "SM_Prop_Lyre_01", "hand": "LeftHand", "h": 0.55, "up": Vector3(0, 1, 0.25), "fwd": Vector3(0.3, 0, 1), "off": Vector3(0.12, 0.1, 0.05)},
	"tympanum": {"mesh": "#tympanum", "hand": "RightHand", "h": 0.28, "up": Vector3(0, 0.2, 1), "fwd": Vector3(0, 1, -0.2), "off": Vector3(0, 0.02, 0.06), "raw": true},
	"scroll": {"mesh": "SM_Prop_Scroll_01", "hand": "RightHand", "h": 0.3, "up": Vector3(0, 1, 0), "fwd": Vector3(0, 0, 1), "off": Vector3(-0.04, 0.03, 0.06), "raw": true},
	"sickle": {"mesh": "SM_Prop_Sickle_01", "hand": "RightHand", "h": 0.42, "up": Vector3(0, 0.3, 1), "fwd": Vector3(0, 1, 0), "off": Vector3(0, 0.0, 0.1), "raw": true},
	"basket": {"mesh": "SM_Prop_Basket_03", "hand": "LeftHand", "h": 0.34, "up": Vector3(0, 1, 0), "fwd": Vector3(0, 0, 1), "off": Vector3(0, -0.02, 0.02), "anchor": "top"},
	"bread": {"mesh": "@Bread", "hand": "RightHand", "h": 0.16, "raw": true, "up": Vector3(0, 1, 0), "fwd": Vector3(1, 0, 0), "off": Vector3(0, 0.04, 0.06)},
	"jug": {"mesh": "SM_Prop_Jug_02", "hand": "RightHand", "h": 0.34, "up": Vector3(0, 1, 0), "fwd": Vector3(0, 0, 1), "off": Vector3(0, 0.0, 0.03), "anchor": "top"},
	"censer": {"mesh": "SM_Prop_Senser_02", "hand": "RightHand", "h": 0.3, "up": Vector3(0, 1, 0), "fwd": Vector3(0, 0, 1), "off": Vector3(0, -0.02, 0.04), "anchor": "top"},
	"spear": {"mesh": "SM_Wep_Spear_01", "hand": "RightHand", "h": 2.1, "up": Vector3(0, 1, 0.05), "fwd": Vector3(1, 0, 0), "off": Vector3(0, 0.25, 0.02)},
	"shield": {"mesh": "SM_Wep_Shield_01", "hand": "LeftHand", "h": 0.9, "up": Vector3(0, 1, 0.1), "fwd": Vector3(0.35, 0, 1), "off": Vector3(0.06, 0.1, 0.12)},
	"hammer": {"mesh": "SM_Prop_Tool_Hammer_01", "hand": "RightHand", "h": 0.3, "up": Vector3(0, 0.5, 1), "fwd": Vector3(0, 1, -0.3), "off": Vector3(0, 0.02, 0.08), "raw": true},
	"razor": {"mesh": "#razor", "hand": "RightHand", "h": 0.14, "up": Vector3(0, 0.2, 1), "fwd": Vector3(0, 1, 0), "off": Vector3(0, 0.02, 0.06), "raw": true},
	# покупки
	"amphora": {"mesh": "SM_Prop_Jug_03", "hand": "LeftHand", "h": 0.4, "up": Vector3(0, 1, 0), "fwd": Vector3(0, 0, 1), "off": Vector3(0, 0.0, 0.03), "anchor": "top"},
	"cloth": {"mesh": "SM_Prop_Rug_Folded_01", "hand": "LeftHand", "h": 0.3, "raw": true, "up": Vector3(0, 1, 0), "fwd": Vector3(1, 0, 0), "off": Vector3(0, 0.05, 0.08)},
	"pot": {"mesh": "SM_Prop_Vase_01", "hand": "LeftHand", "h": 0.3, "up": Vector3(0, 1, 0), "fwd": Vector3(0, 0, 1), "off": Vector3(0, -0.02, 0.03), "anchor": "top"},
	"jar": {"mesh": "SM_Prop_Jar_01", "hand": "LeftHand", "h": 0.2, "up": Vector3(0, 1, 0), "fwd": Vector3(0, 0, 1), "off": Vector3(0, -0.01, 0.04), "anchor": "top"},
}

## Кто что держит на работе: тип постройки → [вещи слота 0, слота 1, …] (пусто — без вещей); clip — своё движение слота
const WORK := {
	"musicians": [["lyre"], ["tympanum"]],
	"scriptorium": [["scroll"]], "school": [["scroll"]], "library": [["scroll"]], "academy": [["scroll"]],
	"farm": [["sickle"], ["sickle"]], "grove": [["basket"]], "vineyard": [["basket"]],
	"bakery": [["bread"]], "taberna": [["jug"], ["jug"]], "thermopolium": [["jug"]],
	"temple": [["censer"]], "barber": [[], ["razor"]],
	"center": [[], ["spear", "shield"]], "forum": [[], ["spear", "shield"]],
}
## Свои движения слотов (вместо записанных в чертеже): музыкант играет на лире, а не говорит «в воздух»
const WORK_CLIP := {"musicians": ["Play_Lyre", ""]}

## Что несут домой из лавки
const CARRY := {
	"stall_fruit": "basket", "stall_veg": "basket", "stall_fish": "basket", "butcher": "basket", "bakery": "basket",
	"wineshop": "amphora", "oilshop": "amphora", "potter": "pot", "weaver": "cloth", "tailor": "cloth", "dyer": "cloth",
	"fullonica": "cloth", "cobbler": "cloth", "lamps": "jar", "perfumer": "jar", "jeweler": "jar", "medic": "jar",
}

static var _grips := {}
static var _meshes := {}


## Вещи слота: [] — без вещей
static func work(type: String, slot: int) -> Array:
	var l: Array = WORK.get(type, [])
	return l[slot] if slot >= 0 and slot < l.size() else []


## Движение слота: своё (лира) или как в чертеже
static func work_clip(type: String, slot: int, clip: String) -> String:
	var l: Array = WORK_CLIP.get(type, [])
	if slot >= 0 and slot < l.size() and String(l[slot]) != "":
		return l[slot]
	return clip


## Что держит житель сейчас ("" — ничего): имена вещей через «+»
static func held(c: Node3D) -> String:
	return str(c.get_meta("hand_props", "")) if c else ""


## Дать в руки вещи whats (уже держит те же — ничего не делает); clip — движение, по позе которого держать
static func hold(c: Citizen, whats: Array, clip: String) -> void:
	var key := "+".join(PackedStringArray(whats))
	if held(c) == key:
		return
	drop(c)
	if whats.is_empty():
		return
	var sks := c.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return
	var sk: Skeleton3D = sks[0]
	for w: String in whats:
		var d: Dictionary = DEF.get(w, {})
		if d.is_empty():
			continue
		var ba := BoneAttachment3D.new()
		ba.name = "HandProp"
		ba.bone_name = d["hand"]
		sk.add_child(ba)
		var holder := Node3D.new()
		ba.add_child(holder)
		var mi := MeshInstance3D.new()
		var mb: Array = _mesh(w)
		mi.mesh = mb[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = mb[1]
		holder.add_child(mi)
		holder.transform = _grip(sk, w, clip)
	c.set_meta("hand_props", key)
	c.meshes = []                          # прозрачность (входит в дверь) — и для вещей


## Убрать вещи из рук
static func drop(c: Node3D) -> void:
	if c == null or held(c) == "":
		return
	for ba in c.find_children("HandProp", "BoneAttachment3D", true, false):
		ba.get_parent().remove_child(ba)
		ba.queue_free()
	c.set_meta("hand_props", "")
	if c is Citizen:
		(c as Citizen).meshes = []


## Как держать: вещь в осях скелета на кадре движения → в осях кисти (на всех жителей одно — скелеты общего стандарта)
static func _grip(sk: Skeleton3D, w: String, clip: String) -> Transform3D:
	var key := w + "|" + clip
	if _grips.has(key):
		return _grips[key]
	var d: Dictionary = DEF[w]
	var a: Animation = Citizen.library().get_animation(clip) if Citizen.library().has_animation(clip) else Citizen.library().get_animation("Idle")
	var g := LegionFighter._pose(sk, a, minf(0.8, a.length * 0.5), d["hand"])
	var want := LegionFighter._basis(d["up"], d["fwd"])
	var xf := g.affine_inverse() * Transform3D(want, g.origin + (d["off"] as Vector3))
	_grips[key] = xf
	return xf


## Сетка вещи одним куском (одна отрисовка) и сдвиг, чтобы хват был в кисти: [сетка, сдвиг]
static func _mesh(w: String) -> Array:
	if _meshes.has(w):
		return _meshes[w]
	var d: Dictionary = DEF[w]
	var nm: String = d["mesh"]
	var m: Mesh
	if nm.begins_with("#"):
		m = _kit(nm)
	else:
		var n: Node3D = Artisau.make(nm.substr(1)) if nm.begins_with("@") else Synty.make(nm)
		m = _merge(n)
		n.free()
	var box := m.get_aabb()
	var s := float(d["h"]) / maxf(0.001, maxf(box.size.y, maxf(box.size.x, box.size.z)) if d.get("raw", false) else box.size.y)
	if nm.begins_with("SM_Wep_Spear"):
		s = float(d["h"]) / maxf(0.001, maxf(box.size.y, maxf(box.size.x, box.size.z)))
	var sm := _scaled(m, s)
	box = sm.get_aabb()
	var at := box.get_center()
	if d.get("anchor", "center") == "top":
		at = Vector3(at.x, box.end.y - box.size.y * 0.08, at.z)
	_meshes[w] = [sm, -at]
	return _meshes[w]


## Все сетки узла (с их преобразованиями и материалами) — в одну ArrayMesh
static func _merge(n: Node3D) -> ArrayMesh:
	var st := SurfaceTool.new()
	var out := ArrayMesh.new()
	var mat: Material = null
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Citizen._rel(mi, n)
		for s in mi.mesh.get_surface_count():
			var sm: Material = mi.get_surface_override_material(s)
			if sm == null:
				sm = mi.material_override if mi.material_override else mi.mesh.surface_get_material(s)
			if mat == null:
				mat = sm
			st.append_from(mi.mesh, s, xf)
	out = st.commit()
	if out.get_surface_count() > 0 and mat:
		out.surface_set_material(0, mat)
	return out


static func _scaled(m: Mesh, s: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.append_from(m, 0, Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO))
	var out := st.commit()
	out.surface_set_material(0, m.surface_get_material(0))
	return out


## Свои мелочи: бубен (обод и кожа), бритва
static func _kit(nm: String) -> Mesh:
	var k := Kit.new()
	match nm:
		"#tympanum":
			k.cyl(Vector3(0, -0.03, 0), 0.5, 0.06, 14, Color("8a5a32"))
			k.cyl(Vector3(0, -0.031, 0), 0.46, 0.062, 14, Color("e8d6b0"))
			for i in 4:
				var a := TAU * i / 4.0
				k.cyl(Vector3(cos(a) * 0.5, -0.02, sin(a) * 0.5), 0.05, 0.04, 6, Color("d4a548"))
		"#razor":
			k.boxc(Vector3(0, 0, 0.0), Vector3(0.12, 0.5, 0.1), Color("6b4a2e"))
			k.boxc(Vector3(0, 0.45, 0.0), Vector3(0.05, 0.4, 0.3), Color("c9c4b8"))
	var am := k.mesh()
	am.surface_set_material(0, Kit.material(0.6))
	return am
