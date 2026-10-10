class_name Citizen
extends Node3D
## Житель: скелет и движения из библиотеки анимаций Quaternius, тело и одежда (туника крестьянина),
## причёска на кости головы. Цвет туники и волос — свой у каждого. Модели — CC0 (assets/people/LICENSE.txt).

const DIR := "res://assets/people/"
const TUNICS := [Color("f3ede0"), Color("e0b86e"), Color("c0603f"), Color("6f8fb3"), Color("7f9a5c"), Color("caa27a"), Color("9a6a9a"), Color("d9c6a0")]
const HAIR_COL := [Color("3a2a1e"), Color("5a3d26"), Color("1f1a17"), Color("8a6a3a"), Color("b48a4a")]

var skel: Skeleton3D
var anim: AnimationPlayer
var rig: Node3D
var female := false
var _cur := ""

static var _cache := {}


static func _scene(name: String) -> PackedScene:
	if not _cache.has(name):
		_cache[name] = load(DIR + name)
	return _cache[name]


static func create(rng: RandomNumberGenerator, is_female: bool, child := false) -> Citizen:
	var c := Citizen.new()
	c.female = is_female
	var rig := _scene("UAL1_Standard.glb").instantiate() as Node3D
	c.rig = rig
	c.add_child(rig)
	c.skel = rig.find_children("*", "Skeleton3D", true, false)[0]
	c.anim = rig.find_children("*", "AnimationPlayer", true, false)[0]
	for m in c.skel.find_children("*", "MeshInstance3D", true, false):
		m.queue_free()                                    # манекен из библиотеки анимаций не нужен
	var tunic: Color = TUNICS[rng.randi() % TUNICS.size()]
	# тело целиком (руки, ноги и ступни видны), поверх — римская туника или стола
	c._wear(_scene(("Superhero_Female_FullBody" if is_female else "Superhero_Male_FullBody") + ".gltf"), Color.WHITE, true)
	var stripe := rng.randf() < 0.3
	c._tunic(tunic, Color("6b4a2e") if rng.randf() < 0.7 else tunic.darkened(0.35), stripe)
	var hairs := ["Hair_Long", "Hair_Long", "Hair_Buns"] if is_female else ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Buzzed"]
	var hc: Color = HAIR_COL[rng.randi() % HAIR_COL.size()]
	c._hair(hairs[rng.randi() % hairs.size()], hc)
	c._hair("Eyebrows_Female" if is_female else "Eyebrows_Regular", hc)
	if not is_female and rng.randf() < 0.4:
		c._hair("Hair_Beard", hc)
	if child:
		c.scale = Vector3.ONE * 0.72
	return c


## Перенести сетки из модели на наш скелет (кости называются одинаково)
func _wear(ps: PackedScene, tint: Color, head_only: bool) -> void:
	var src := ps.instantiate()
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		if head_only:
			if mi.name == "Eyebrows":
				continue                          # брови — отдельной сеткой ниже, своего цвета
			if String(mi.name).to_lower().begins_with("superhero"):
				# под туникой тела не видно — вырезаем его, чтобы не протыкало ткань на ходу
				mi.mesh = _cut_body(mi.mesh, 0.12 if female else 0.56, 1.37)
		var skin := mi.skin
		mi.owner = null
		mi.get_parent().remove_child(mi)
		skel.add_child(mi)
		mi.skin = skin
		mi.skeleton = NodePath("..")
		if tint != Color.WHITE:
			for s in mi.get_surface_override_material_count():
				var base := mi.mesh.surface_get_material(s)
				if base is StandardMaterial3D and base.resource_name == "MI_Peasant":
					var m := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
					m.albedo_color = tint.lerp(Color.WHITE, 0.3)
					mi.set_surface_override_material(s, m)
	src.queue_free()


## Тело без части, закрытой одеждой: убираем треугольники туловища и бёдер между lo и hi (руки в позе покоя — в стороны, их не трогаем)
static func _cut_body(mesh: Mesh, lo: float, hi: float) -> Mesh:
	var key := "cut:" + str(mesh.get_instance_id()) + ":" + str(lo)
	if _cache.has(key):
		return _cache[key]
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for t in range(0, ix.size(), 3):
			var c := (v[ix[t]] + v[ix[t + 1]] + v[ix[t + 2]]) / 3.0
			if c.y > lo and c.y < hi and absf(c.x) < 0.3:
				continue
			if c.y > 1.3 and c.y < 1.49 and absf(c.x) < 0.33 and absf(c.x) > 0.06:
				continue                            # плечи и руки до локтя — под рукавами
			keep.append_array([ix[t], ix[t + 1], ix[t + 2]])
		arr[Mesh.ARRAY_INDEX] = keep
		for ci in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[ci] = null                      # служебные массивы импорта не нужны
		var flags: int = mesh.surface_get_format(si) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		out.surface_set_material(si, mesh.surface_get_material(si))
	_cache[key] = out
	return out


## Голова от базового тела: оставляем только треугольники выше плеч (в позе покоя)
static func _head_only(mesh: Mesh) -> Mesh:
	var key := "head:" + str(mesh.get_instance_id())
	if _cache.has(key):
		return _cache[key]
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var top := -1e9
		for p in v:
			top = maxf(top, p.y)
		var cut := top * 0.8                 # шея — на 80% роста
		var keep := PackedInt32Array()
		for t in range(0, ix.size(), 3):
			if v[ix[t]].y > cut and v[ix[t + 1]].y > cut and v[ix[t + 2]].y > cut:
				keep.append_array([ix[t], ix[t + 1], ix[t + 2]])
		arr[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mesh.surface_get_format(si) & ~Mesh.ARRAY_FORMAT_INDEX | Mesh.ARRAY_FORMAT_INDEX)
		out.surface_set_material(si, mesh.surface_get_material(si))
	_cache[key] = out
	return out


# ---------- римская одежда: сетка, привязанная к костям ----------

const BONES := ["spine_03", "spine_02", "spine_01", "pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r", "upperarm_l", "upperarm_r", "clavicle_l", "clavicle_r"]


func _skin() -> Skin:
	var sk := Skin.new()
	for b in BONES:
		sk.add_named_bind(b, skel.get_bone_global_rest(skel.find_bone(b)).affine_inverse())
	return sk


## Сборка одежды: у каждой вершины — до четырёх костей с весами
class Cloth:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var bi := PackedInt32Array()
	var bw := PackedFloat32Array()

	func vert(p: Vector3, nrm: Vector3, col: Color, w: Dictionary) -> void:
		v.append(p)
		n.append(nrm)
		c.append(col)
		var keys := w.keys()
		keys.sort_custom(func(a, b): return w[a] > w[b])
		var tot := 0.0
		for i in mini(4, keys.size()):
			tot += float(w[keys[i]])
		for i in 4:
			if i < keys.size():
				bi.append(Citizen.BONES.find(keys[i]))
				bw.append(float(w[keys[i]]) / maxf(tot, 1e-6))
			else:
				bi.append(0)
				bw.append(0.0)

	## треугольник лицом от оси (ax — точка на оси), в буфер — по часовой, как лицевая сторона в Godot
	func tri(a: Array, b: Array, d: Array, ax: Vector3) -> void:
		var pa: Vector3 = a[0]
		var pb: Vector3 = b[0]
		var pd: Vector3 = d[0]
		var nn := (pb - pa).cross(pd - pa)
		if nn.dot((pa + pb + pd) / 3.0 - ax) < 0.0:
			var t := b
			b = d
			d = t
			nn = -nn
		nn = nn.normalized()
		for q: Array in [a, d, b]:
			vert(q[0], nn, q[1], q[2])

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_BONES] = bi
		arr[Mesh.ARRAY_WEIGHTS] = bw
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


func _cloth_node(cl: Cloth) -> void:
	var sk := _skin()
	var mi := MeshInstance3D.new()
	mi.mesh = cl.mesh()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.9
	mi.material_override = mat
	skel.add_child(mi)
	mi.skin = sk
	mi.skeleton = NodePath("..")


## Вес по высоте: верх — за позвоночник, пояс — за таз, подол — за бёдра своей стороны (у столы ниже — и за голени)
func _w(y: float, x: float, rx: float) -> Dictionary:
	if y > 1.3:
		return {"spine_03": 1.0}
	if y > 1.15:
		return {"spine_03": (y - 1.15) / 0.15, "spine_02": 1.0 - (y - 1.15) / 0.15}
	if y > 1.02:
		return {"spine_02": (y - 1.02) / 0.13, "spine_01": 1.0 - (y - 1.02) / 0.13}
	if y > 0.9:
		return {"spine_01": (y - 0.9) / 0.12, "pelvis": 1.0 - (y - 0.9) / 0.12}
	var leg := clampf((0.9 - y) / 0.35, 0.0, 1.0)
	var side := smoothstep(-0.55, 0.55, x / rx)          # 1 — левый бок, 0 — правый
	var d := {"pelvis": 1.0 - leg}
	if y > 0.5:
		d["thigh_l"] = leg * side
		d["thigh_r"] = leg * (1.0 - side)
	else:
		var low := clampf((0.5 - y) / 0.4, 0.0, 1.0) * 0.5
		d["thigh_l"] = leg * side * (1.0 - low)
		d["thigh_r"] = leg * (1.0 - side) * (1.0 - low)
		d["calf_l"] = leg * side * low
		d["calf_r"] = leg * (1.0 - side) * low
	return d


## Туника (у мужчин до колен) или стола (у женщин до пят): кольца от ворота до подола, пояс, короткие рукава
func _tunic(col: Color, belt: Color, stripes: bool) -> void:
	var rings := [[1.505, 0.085, 0.07, -0.01], [1.465, 0.2, 0.125, -0.01], [1.4, 0.225, 0.14, 0.0], [1.3, 0.21, 0.148, 0.01], [1.15, 0.178, 0.137, 0.01],
		[1.02, 0.18, 0.14, 0.0], [0.9, 0.205, 0.155, -0.02], [0.72, 0.235, 0.175, -0.01]]
	if female:
		rings.append_array([[0.52, 0.255, 0.19, 0.0], [0.3, 0.27, 0.2, 0.0], [0.08, 0.285, 0.21, 0.0]])
	else:
		rings.append([0.5, 0.27, 0.195, 0.0])
	var cl := Cloth.new()
	var seg := 14
	var stripe := Color("a8322a")
	for r in rings.size() - 1:
		var a0: Array = rings[r]
		var a1: Array = rings[r + 1]
		var ax := Vector3(0, (float(a0[0]) + float(a1[0])) * 0.5, float(a0[3]))
		for i in seg:
			var t0 := TAU * i / seg
			var t1 := TAU * (i + 1) / seg
			var pts := []
			for q: Array in [[a0, t0], [a1, t0], [a1, t1], [a0, t1]]:
				var rr: Array = q[0]
				var t: float = q[1]
				var p := Vector3(cos(t) * float(rr[1]), float(rr[0]), float(rr[3]) + sin(t) * float(rr[2]))
				# клавы — две вертикальные полосы спереди и сзади
				var cc := col
				if stripes and absf(absf(cos(t)) - 0.38) < 0.13:
					cc = stripe
				pts.append([p, cc.lightened(0.04 * sin(t * 3.0)), _w(p.y, p.x, float(rr[1]))])
			cl.tri(pts[0], pts[1], pts[2], ax)
			cl.tri(pts[0], pts[2], pts[3], ax)
	# пояс
	var by := 1.03
	for i in seg:
		var t0 := TAU * i / seg
		var t1 := TAU * (i + 1) / seg
		var q := []
		for pr: Array in [[t0, by - 0.035], [t0, by + 0.035], [t1, by + 0.035], [t1, by - 0.035]]:
			var p := Vector3(cos(float(pr[0])) * 0.188, float(pr[1]), 0.006 + sin(float(pr[0])) * 0.148)
			q.append([p, belt, _w(p.y, p.x, 0.19)])
		cl.tri(q[0], q[1], q[2], Vector3(0, by, 0.006))
		cl.tri(q[0], q[2], q[3], Vector3(0, by, 0.006))
	# короткие рукава вдоль рук (в позе покоя руки разведены в стороны)
	for s: float in [1.0, -1.0]:
		var bone := "upperarm_l" if s > 0 else "upperarm_r"
		var clav := "clavicle_l" if s > 0 else "clavicle_r"
		for i in 8:
			var t0 := TAU * i / 8
			var t1 := TAU * (i + 1) / 8
			var q := []
			for pr: Array in [[0.15, t0, 0.095], [0.34, t0, 0.078], [0.34, t1, 0.078], [0.15, t1, 0.095]]:
				var px: float = pr[0]
				var pt: float = pr[1]
				var pr_r: float = pr[2]
				var p := Vector3(s * px, 1.43 + cos(pt) * pr_r, -0.065 + sin(pt) * pr_r * 0.95)
				var w := {bone: 1.0} if px > 0.2 else {bone: 0.6, clav: 0.2, "spine_03": 0.2}
				q.append([p, col.darkened(0.03), w])
			cl.tri(q[0], q[1], q[2], Vector3(s * 0.25, 1.43, -0.065))
			cl.tri(q[0], q[2], q[3], Vector3(s * 0.25, 1.43, -0.065))
	_cloth_node(cl)


## Палла — накидка на плечи у женщин: широкий воротник, сзади спадает ниже
func _palla(col: Color) -> void:
	var cl := Cloth.new()
	var seg := 14
	var rings := [[1.48, 0.15, 0.1], [1.42, 0.25, 0.16], [1.3, 0.265, 0.175]]
	for r in rings.size() - 1:
		var a0: Array = rings[r]
		var a1: Array = rings[r + 1]
		var ax := Vector3(0, 1.4, 0)
		for i in seg:
			var t0 := TAU * i / seg
			var t1 := TAU * (i + 1) / seg
			var pts := []
			for q: Array in [[a0, t0, r], [a1, t0, r + 1], [a1, t1, r + 1], [a0, t1, r]]:
				var rr: Array = q[0]
				var t: float = q[1]
				var back := clampf(-sin(t), 0.0, 1.0)
				var y: float = float(rr[0]) - (0.35 * back if int(q[2]) == rings.size() - 1 else 0.0)
				var p := Vector3(cos(t) * float(rr[1]), y, -0.01 + sin(t) * float(rr[2]))
				pts.append([p, col, {"spine_03": 1.0}])
			cl.tri(pts[0], pts[1], pts[2], ax)
			cl.tri(pts[0], pts[2], pts[3], ax)
	_cloth_node(cl)


## Причёска — неподвижная сетка «на голове в начале координат»: вешаем на кость головы
func _hair(name: String, col: Color) -> void:
	var src := _scene(name + ".gltf").instantiate()
	var bone := skel.find_bone("Head")
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	skel.add_child(att)
	# причёска сделана под голову своего тела: смещение берём от скелета этого тела, а не от библиотеки движений
	var rest := _body_head_rest(female)
	var sk := Transform3D.IDENTITY
	for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
		var xf := _world_xf(mi)
		mi.owner = null
		mi.get_parent().remove_child(mi)
		att.add_child(mi)
		mi.transform = rest.affine_inverse() * sk.affine_inverse() * xf
		for s in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var m := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.albedo_color = col
				mi.set_surface_override_material(s, m)
	src.queue_free()


static func _body_head_rest(is_female: bool) -> Transform3D:
	var key := "headrest:" + str(is_female)
	if not _cache.has(key):
		var b := _scene(("Superhero_Female_FullBody" if is_female else "Superhero_Male_FullBody") + ".gltf").instantiate()
		var sk: Skeleton3D = b.find_children("*", "Skeleton3D", true, false)[0]
		_cache[key] = _rel(sk, b) * sk.get_bone_global_rest(sk.find_bone("Head"))
		b.queue_free()
	return _cache[key]


## Преобразование узла относительно предка top (сам top не входит)
static func _rel(n: Node3D, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var p: Node = n
	while p != top and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func _world_xf(n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func play(name: String, blend := 0.25) -> void:
	if name == _cur:
		return
	_cur = name
	var full := name
	if not anim.has_animation(full) and anim.has_animation(name.trim_suffix("_Loop")):
		full = name.trim_suffix("_Loop")      # при импорте Godot убирает «_Loop» и сам зацикливает
	if not anim.has_animation(full):
		for n in anim.get_animation_list():
			if n.ends_with(name):
				full = n
				break
	anim.play(full, blend)
