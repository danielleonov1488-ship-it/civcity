class_name Crowd
extends Node3D
## Толпа: сотни сидящих (и идущих) людей без потери кадров. Обычный житель (Citizen) — свой скелет и проигрыватель
## движений: сотня таких уже заметна, а на трибунах их многие сотни. Здесь у каждой модели Synty позы костей всех
## нужных движений один раз «запекаются» в картинку (shaders/crowd.gdshader), а люди рисуются пачками MultiMesh:
## одна пачка на модель и тон кожи, ещё по пачке на причёску, бороду и венок. Цвета одежды — как у жителей.
## Сидящим на ступенях трибун позы чуть поправлены: ступени ниже скамьи, поэтому колени выше, а ступни ровно стоят
## на ступени ниже (SEAT_DROP); хлопки, «ура» и наклон вперёд собраны из сидячей позы (руки — по точкам, IK).
## Человек толпы — словарь (add): у него свои клип, время начала, место; меняется play/move, убирается remove.

const FPS := 30.0
const SIZE := Citizen.SIZE
const SEAT_RISE := 0.30 * Citizen.K   # обычное сидение: таз над ступнями (как People.SIT_SEAT)
const SEAT_DROP := 0.19          # ступень трибуны: от сиденья до ступени ниже (колизей, театр, цирк — одинаково)
const BLEND := 0.35
## Клипы: имя, движение-источник, петля, правка позы
const CLIPS := [
	["sit", "Sitting_Idle", true, "seat"],
	["sit_m", "Sitting_Idle_M", true, "seat"],
	["talk", "Sitting_Talking", true, "seat"],
	["talk_m", "Sitting_Talking_M", true, "seat"],
	["clap", "Sitting_Idle", true, "clap"],
	["cheer", "Sitting_Idle", true, "cheer"],
	["cheer_m", "Sitting_Idle_M", true, "cheer_l"],
	["lean", "Sitting_Idle", true, "lean"],
	["enter", "Sitting_Enter", false, "enter"],
	["walk", "Walk", true, ""],
	["stand", "Idle", true, ""],
	["drive", "Idle", true, "drive"],
]
## Длина собранных клипов (с), чтобы движение рук укладывалось в круг целое число раз
const DERIVED_LEN := {"clap": 3.333, "cheer": 3.333, "cheer_l": 3.333, "lean": 3.333, "drive": 2.5}

static var _clip_idx := {}       # имя клипа → номер
static var _clip_tab := []       # [первая строка, кадров, петля, fps] по номерам
static var _rows := 0
static var _rigs := {}           # модель → {tex, binds, head, body: ArrayMesh, mask: [main, second, trim]}
static var _hairs := {}          # причёска|модель → ArrayMesh
static var _mats := {}
static var _shader: Shader
static var _palette: Image
static var _pal_tex: ImageTexture
static var _pal := {}            # html цвета → номер в палитре
static var _now_frame := -1

var groups := {}                 # ключ пачки → {mm, mi, who: [человек по номеру]}


static func clip_id(name: String) -> int:
	_tables()
	return int(_clip_idx.get(name, 0))


static func clip_len(name: String) -> float:
	_tables()
	var c: Array = _clip_tab[clip_id(name)]
	return float(c[1]) / float(c[3])


static func now() -> float:
	return AnimClock.now()


## Таблица клипов: строки картинки поз по порядку клипов (у всех моделей одинаковая)
static func _tables() -> void:
	if not _clip_idx.is_empty():
		return
	var lib := Citizen.library()
	var row := 0
	for i in CLIPS.size():
		var c: Array = CLIPS[i]
		var L := DERIVED_LEN.get(c[3], lib.get_animation(c[1]).length) as float
		var n := maxi(2, int(round(L * FPS)))         # петля: кадр n совпал бы с кадром 0 — его нет
		_clip_idx[c[0]] = i
		_clip_tab.append([row, n, 1.0 if c[2] else 0.0, FPS])
		row += n
	_rows = row


# ---------- запекание поз ----------

## Модель: скелет, кости скина, тело с номерами и весами костей в CUSTOM0/1, картинка поз всех клипов
static func rig(mdl: String) -> Dictionary:
	if _rigs.has(mdl):
		return _rigs[mdl]
	_tables()
	Synty._index()
	var body := Citizen._scene(Citizen.DIR + mdl + ".fbx").instantiate() as Node3D
	var sk: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = null
	for m: MeshInstance3D in body.find_children("*", "MeshInstance3D", true, false):
		if m.skin != null:
			mi = m
			break
	var skin: Skin = mi.skin
	var nb := sk.get_bone_count()
	var parent := PackedInt32Array()
	var rest: Array[Transform3D] = []
	var names := {}
	for b in nb:
		parent.append(sk.get_bone_parent(b))
		rest.append(sk.get_bone_rest(b))
		names[sk.get_bone_name(b)] = b
	var binds := skin.get_bind_count()
	var bind_bone := PackedInt32Array()
	var bind_pose: Array[Transform3D] = []
	var head := 0
	for i in binds:
		var bb := skin.get_bind_bone(i)
		if bb < 0:
			bb = sk.find_bone(skin.get_bind_name(i))
		bind_bone.append(bb)
		bind_pose.append(skin.get_bind_pose(i))
		if bb == int(names.get("Head", -1)):
			head = i
	var R := {"mdl": mdl, "parent": parent, "rest": rest, "names": names, "binds": binds, "bind_bone": bind_bone,
		"bind_pose": bind_pose, "head": head}
	R["body"] = _skin_mesh(mi.mesh, binds)
	var map: Dictionary = Citizen.CLOTH.get(mdl, {})
	R["mask"] = [Citizen._bits(map.get("main", [])), Citizen._bits(map.get("second", [])), Citizen._bits(map.get("trim", []))]
	R["k"] = float(map.get("k", 1.0))
	body.free()
	var t0 := Time.get_ticks_msec()
	var img := _bake(R)
	R["tex"] = ImageTexture.create_from_image(img)
	R["bake_ms"] = Time.get_ticks_msec() - t0
	_rigs[mdl] = R
	return R


## Сетка тела: те же вершины, номера костей скина — CUSTOM0, веса — CUSTOM1 (из 8 весов — 4 самых больших)
static func _skin_mesh(src: Mesh, binds: int) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var a := src.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nv := v.size()
		var bo = a[Mesh.ARRAY_BONES]
		var we = a[Mesh.ARRAY_WEIGHTS]
		var per: int = (bo as Array).size() / maxi(nv, 1) if bo != null else 0
		var c0 := PackedFloat32Array()
		var c1 := PackedFloat32Array()
		c0.resize(nv * 4)
		c1.resize(nv * 4)
		for i in nv:
			var best := []
			for k in per:
				var w := float(we[i * per + k])
				if w > 0.0:
					best.append([w, int(bo[i * per + k])])
			best.sort_custom(func(x, y): return x[0] > y[0])
			var sum := 0.0
			for k in mini(4, best.size()):
				sum += float(best[k][0])
			for k in 4:
				if k < best.size() and sum > 0.0:
					c0[i * 4 + k] = float(clampi(int(best[k][1]), 0, binds - 1))
					c1[i * 4 + k] = float(best[k][0]) / sum
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = a[Mesh.ARRAY_NORMAL]
		arr[Mesh.ARRAY_TEX_UV] = a[Mesh.ARRAY_TEX_UV]
		arr[Mesh.ARRAY_INDEX] = a[Mesh.ARRAY_INDEX]
		arr[Mesh.ARRAY_CUSTOM0] = c0
		arr[Mesh.ARRAY_CUSTOM1] = c1
		var fl := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fl)
	# вершины ходят за костями далеко от позы покоя: коробка с запасом (сидит, руки вверх)
	out.custom_aabb = AABB(Vector3(-1.2, -0.6, -1.2), Vector3(2.4, 3.0, 2.4))
	return out


## Причёска (борода, венок) модели: жёстко на кости головы — вершины в осях кости скина (bind), вес 1
static func hair_mesh(hair: String, mdl: String) -> ArrayMesh:
	var key := hair + "|" + mdl
	if _hairs.has(key):
		return _hairs[key]
	var R := rig(mdl)
	var inv: Transform3D = (R["bind_pose"][R["head"]] as Transform3D).affine_inverse()
	var hn := Citizen._scene("res://assets/synty/FBX/Attachments/" + hair + ".fbx").instantiate() as Node3D
	var out := ArrayMesh.new()
	for mi: MeshInstance3D in hn.find_children("*", "MeshInstance3D", true, false):
		var rel := Citizen._rel(mi, hn)
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var xf := inv * rel
			var nb := xf.basis.inverse().transposed()
			var v2 := PackedVector3Array()
			var n2 := PackedVector3Array()
			v2.resize(v.size())
			n2.resize(v.size())
			var c0 := PackedFloat32Array()
			var c1 := PackedFloat32Array()
			c0.resize(v.size() * 4)
			c1.resize(v.size() * 4)
			for i in v.size():
				v2[i] = xf * v[i]
				n2[i] = (nb * nn[i]).normalized()
				c0[i * 4] = float(R["head"])
				c1[i * 4] = 1.0
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = v2
			arr[Mesh.ARRAY_NORMAL] = n2
			arr[Mesh.ARRAY_TEX_UV] = a[Mesh.ARRAY_TEX_UV]
			arr[Mesh.ARRAY_INDEX] = a[Mesh.ARRAY_INDEX]
			arr[Mesh.ARRAY_CUSTOM0] = c0
			arr[Mesh.ARRAY_CUSTOM1] = c1
			var fl := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fl)
	hn.free()
	out.custom_aabb = AABB(Vector3(-1.2, -0.6, -1.2), Vector3(2.4, 3.0, 2.4))
	_hairs[key] = out
	return out


## Все клипы модели — в картинку: строка на кадр, три текселя (строки матрицы 3×4) на кость скина
static func _bake(R: Dictionary) -> Image:
	var lib := Citizen.library()
	var binds: int = R["binds"]
	var W := binds * 3
	var data := PackedFloat32Array()
	data.resize(W * _rows * 4)
	var S := _Skel.new(R)
	for ci in CLIPS.size():
		var c: Array = CLIPS[ci]
		var tab: Array = _clip_tab[ci]
		var a := lib.get_animation(c[1])
		var n: int = tab[1]
		var how: String = c[3]
		var L := float(n) / FPS
		for f in n:
			var t := f / FPS
			S.pose(a, fmod(t, a.length) if DERIVED_LEN.has(how) else minf(t, a.length))
			S.fix(how, t, L)
			var row: int = int(tab[0]) + f
			for i in binds:
				var m: Transform3D = S.glob[R["bind_bone"][i]] * (R["bind_pose"][i] as Transform3D)
				var o := (row * W + i * 3) * 4
				var bx := m.basis.x
				var by := m.basis.y
				var bz := m.basis.z
				data[o] = bx.x; data[o + 1] = by.x; data[o + 2] = bz.x; data[o + 3] = m.origin.x
				data[o + 4] = bx.y; data[o + 5] = by.y; data[o + 6] = bz.y; data[o + 7] = m.origin.y
				data[o + 8] = bx.z; data[o + 9] = by.z; data[o + 10] = bz.z; data[o + 11] = m.origin.z
	return Image.create_from_data(W, _rows, false, Image.FORMAT_RGBAF, data.to_byte_array())


## Скелет без узлов: локальные и мировые (в осях модели) позы костей, правки поз
class _Skel:
	var R: Dictionary
	var nb := 0
	var parent: PackedInt32Array
	var loc: Array[Transform3D] = []
	var glob: Array[Transform3D] = []
	var bi := {}
	var tracks := {}              # движение → [[кость, вид, дорожка]]

	func _init(r: Dictionary) -> void:
		R = r
		parent = R["parent"]
		nb = parent.size()
		loc.resize(nb)
		glob.resize(nb)
		bi = R["names"]

	func b(name: String) -> int:
		return int(bi.get(name, -1))

	func solve() -> void:
		for i in nb:
			var p := parent[i]
			glob[i] = glob[p] * loc[i] if p >= 0 else loc[i]

	func set_glob(i: int, g: Transform3D) -> void:
		var p := parent[i]
		loc[i] = glob[p].affine_inverse() * g if p >= 0 else g
		solve()

	## Поза движения a в момент t: кости без дорожек — в покое
	func pose(a: Animation, t: float) -> void:
		var rest: Array[Transform3D] = R["rest"]
		var rot := []
		var pos := []
		var scl := []
		rot.resize(nb)
		pos.resize(nb)
		scl.resize(nb)
		var key := a.get_instance_id()
		if not tracks.has(key):
			var lst := []
			for k in a.get_track_count():
				var bone := b(String(a.track_get_path(k)).get_slice(":", 1))
				if bone >= 0:
					lst.append([bone, a.track_get_type(k), k])
			tracks[key] = lst
		for e: Array in tracks[key]:
			match int(e[1]):
				Animation.TYPE_ROTATION_3D:
					rot[e[0]] = a.rotation_track_interpolate(e[2], t)
				Animation.TYPE_POSITION_3D:
					pos[e[0]] = a.position_track_interpolate(e[2], t)
				Animation.TYPE_SCALE_3D:
					scl[e[0]] = a.scale_track_interpolate(e[2], t)
		for i in nb:
			var r := rest[i]
			var q: Quaternion = rot[i] if rot[i] != null else r.basis.get_rotation_quaternion()
			var s: Vector3 = scl[i] if scl[i] != null else r.basis.get_scale()
			var o: Vector3 = pos[i] if pos[i] != null else r.origin
			loc[i] = Transform3D(Basis(q).scaled(s), o)
		solve()

	## Правки позы по виду клипа (t — время в клипе, L — его длина)
	func fix(how: String, t: float, L: float) -> void:
		var lift := (SEAT_RISE - SEAT_DROP) / SIZE
		match how:
			"seat":
				_legs(lift, 1.0)
			"clap":
				_legs(lift, 1.0)
				_clap(t)
			"cheer":
				_legs(lift, 1.0)
				_cheer(t, L, "Right")
			"cheer_l":
				_legs(lift, 1.0)
				_cheer(t, L, "Left")
			"lean":
				_legs(lift, 1.0)
				_lean(t, L)
			"drive":
				_drive(t, L)
			"enter":
				# садится: стоит на ступени (всё тело выше на lift), к концу таз опускается на сиденье, а ступни
				# остаются на ступени — поднимаются к тазу
				var w := smoothstep(0.35, 1.0, t / L)
				var hips := b("Hips")
				var g := glob[hips]
				g.origin.y += lift * (1.0 - w)
				set_glob(hips, g)
				_legs(lift, w)

	## Ступни выше на lift·w относительно таза (колени поднимаются), подошва остаётся ровной
	func _legs(lift: float, w: float) -> void:
		for side: String in ["Left", "Right"]:
			var up := b(side + "UpperLeg")
			var lo := b(side + "LowerLeg")
			var ft := b(side + "Foot")
			var foot_basis := glob[ft].basis
			var tgt := glob[ft].origin + Vector3(0, lift * w, 0)
			_ik(up, lo, ft, tgt, Vector3(0, 0.3, 1.0))
			var g := glob[ft]
			g.basis = foot_basis
			set_glob(ft, g)

	## Две кости (a — плечо или бедро, m — локоть или колено, e — кисть или стопа): конец — в tgt, сгиб — к pole
	func _ik(a: int, m: int, e: int, tgt: Vector3, pole_hint: Vector3) -> void:
		var A := glob[a].origin
		var M := glob[m].origin
		var E := glob[e].origin
		var l1 := A.distance_to(M)
		var l2 := M.distance_to(E)
		var d := clampf(A.distance_to(tgt), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
		var u := (tgt - A).normalized()
		var pole := (M - A) - u * (M - A).dot(u)
		if pole.length() < 0.01 * l1:
			pole = pole_hint - u * pole_hint.dot(u)
		pole = pole.normalized()
		var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
		var M2 := A + u * x + pole * h
		_turn(a, M - A, M2 - A)
		E = glob[e].origin
		M = glob[m].origin
		_turn(m, E - M, (A + u * d) - M)

	## Повернуть кость i вокруг её сустава так, чтобы направление from стало to
	func _turn(i: int, from: Vector3, to: Vector3) -> void:
		if from.length() < 1e-6 or to.length() < 1e-6:
			return
		var q := Quaternion(from.normalized(), to.normalized())
		var g := glob[i]
		g.basis = Basis(q) * g.basis
		set_glob(i, g)

	## Оси тела: вперёд (куда смотрят ступни), вверх, влево (к левому плечу)
	func _frame() -> Array:
		var fwd := ((glob[b("LeftToes")].origin + glob[b("RightToes")].origin) - (glob[b("LeftFoot")].origin + glob[b("RightFoot")].origin)) * 0.5
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 1e-4 else Vector3(0, 0, 1)
		var left := glob[b("LeftUpperArm")].origin - glob[b("RightUpperArm")].origin
		left = (left - fwd * left.dot(fwd))
		left.y = 0.0
		left = left.normalized()
		return [fwd, Vector3.UP, left]

	## Хлопает: кисти перед грудью сходятся и расходятся (8 хлопков за круг)
	func _clap(t: float) -> void:
		var fr := _frame()
		var fwd: Vector3 = fr[0]
		var left: Vector3 = fr[2]
		var la := b("LeftUpperArm")
		var ra := b("RightUpperArm")
		var sh := glob[la].origin.distance_to(glob[ra].origin)
		var c := (glob[la].origin + glob[ra].origin) * 0.5
		var ph := t * 8.0 / 3.333
		var gap := sh * (0.06 + 0.3 * (0.5 - 0.5 * cos(TAU * ph)))
		var at := c + fwd * sh * 1.05 - Vector3.UP * sh * 0.35
		_ik(la, b("LeftLowerArm"), b("LeftHand"), at + left * gap * 0.5, left - Vector3.UP)
		_ik(ra, b("RightLowerArm"), b("RightHand"), at - left * gap * 0.5, -left - Vector3.UP)

	## «Ура»: рука вверх, кулак качается (3 взмаха за круг); второй рукой — как сидел
	func _cheer(t: float, L: float, side: String) -> void:
		var fr := _frame()
		var fwd: Vector3 = fr[0]
		var left: Vector3 = fr[2]
		var s := 1.0 if side == "Left" else -1.0
		var ua := b(side + "UpperArm")
		var la := b(side + "LowerArm")
		var hd := b(side + "Hand")
		var arm := glob[ua].origin.distance_to(glob[la].origin) + glob[la].origin.distance_to(glob[hd].origin)
		var ph := t * 3.0 / L
		var pump := 0.5 - 0.5 * cos(TAU * ph)
		var at := glob[ua].origin + Vector3.UP * arm * (0.78 + 0.14 * pump) + fwd * arm * 0.22 + left * s * arm * 0.12
		_ik(ua, la, hd, at, left * s - fwd * 0.3)

	## Возничий колесницы: стоит, чуть присев (колени пружинят на ходу), подался вперёд, обе руки впереди — держат вожжи
	func _drive(t: float, L: float) -> void:
		var fr := _frame()
		var fwd: Vector3 = fr[0]
		var left: Vector3 = fr[2]
		var feet := [glob[b("LeftFoot")], glob[b("RightFoot")]]
		var hips := b("Hips")
		var g := glob[hips]
		g.origin.y -= 0.07 + 0.012 * sin(TAU * t * 7.0 / L)
		g.origin -= fwd * 0.03
		set_glob(hips, g)
		var k := 0
		for side: String in ["Left", "Right"]:
			var ft := b(side + "Foot")
			var fb: Transform3D = feet[k]
			_ik(b(side + "UpperLeg"), b(side + "LowerLeg"), ft, fb.origin, fwd + Vector3.UP * 0.2)
			var gf := glob[ft]
			gf.basis = fb.basis
			set_glob(ft, gf)
			k += 1
		var ax := Vector3.UP.cross(fwd).normalized()
		for e: Array in [["Spine", 0.22], ["Chest", 0.12]]:
			var i := b(e[0])
			var gs := glob[i]
			gs.basis = Basis(ax, float(e[1])) * gs.basis
			set_glob(i, gs)
		var hd := b("Head")
		var gh := glob[hd]
		gh.basis = Basis(ax, -0.25) * gh.basis
		set_glob(hd, gh)
		var la := b("LeftUpperArm")
		var ra := b("RightUpperArm")
		var sh := glob[la].origin.distance_to(glob[ra].origin)
		var c := (glob[la].origin + glob[ra].origin) * 0.5
		var at := c + fwd * sh * 1.25 - Vector3.UP * sh * 0.55 + Vector3.UP * sh * 0.04 * sin(TAU * t * 7.0 / L)
		_ik(la, b("LeftLowerArm"), b("LeftHand"), at + left * sh * 0.22, left - Vector3.UP)
		_ik(ra, b("RightLowerArm"), b("RightHand"), at - left * sh * 0.22, -left - Vector3.UP)

	## Подался вперёд (смотрит, затаив дыхание): спина наклонена, голова чуть поднята, руки на коленях
	func _lean(t: float, L: float) -> void:
		var fr := _frame()
		var ax := Vector3.UP.cross(fr[0] as Vector3).normalized()    # поворот вокруг ax на +угол клонит вперёд
		var k := 0.85 + 0.15 * sin(TAU * t / L)
		for e: Array in [["Spine", 0.16], ["Chest", 0.1]]:
			var i := b(e[0])
			var g := glob[i]
			g.basis = Basis(ax, float(e[1]) * k) * g.basis
			set_glob(i, g)
		var hd := b("Head")
		var g := glob[hd]
		g.basis = Basis(ax, -0.2 * k) * g.basis
		set_glob(hd, g)


# ---------- палитра и материалы ----------

## Номер цвета (линейного) в общей палитре
static func pal(col: Color) -> int:
	if _palette == null:
		_palette = Image.create(256, 1, false, Image.FORMAT_RGBAF)
		_palette.fill(Color(1, 1, 1))
		_pal_tex = ImageTexture.create_from_image(_palette)
		_pal["#"] = 0
	var key := col.to_html(false)
	if _pal.has(key):
		return _pal[key]
	var i := _pal.size()
	if i >= 256:
		return 0
	_pal[key] = i
	_palette.set_pixel(i, 0, col)
	_pal_tex.update(_palette)
	return i


static func _material(kind: String, R: Dictionary, variant: String, flat := false) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [kind, R["mdl"], variant, str(flat)]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = load("res://shaders/crowd.gdshader")
		_global()
	pal(Color.WHITE)
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("bones", R["tex"])
	m.set_shader_parameter("palette", _pal_tex)
	var tab := []
	for c: Array in _clip_tab:
		tab.append(Vector4(c[0], c[1], c[2], c[3]))
	m.set_shader_parameter("clips", tab)
	m.set_shader_parameter("albedo_tex", Gfx.tex(Synty._tex_path("PolygonAncientEmpire_01_" + variant)))
	if kind == "body":
		m.set_shader_parameter("mode", 0)
		m.set_shader_parameter("mask_main", R["mask"][0])
		m.set_shader_parameter("mask_second", R["mask"][1])
		m.set_shader_parameter("mask_trim", R["mask"][2])
	else:
		m.set_shader_parameter("mode", 2 if flat else 1)
	_mats[key] = m
	return m


# ---------- люди толпы ----------

static var _glob := false


## Общее время толпы для шейдера (global uniform crowd_now) — заводится один раз
static func _global() -> void:
	if not _glob:
		_glob = true
		RenderingServer.global_shader_parameter_add("crowd_now", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, now())


func _process(_dt: float) -> void:
	_global()
	var f := Engine.get_process_frames()
	if f != _now_frame:
		_now_frame = f
		RenderingServer.global_shader_parameter_set("crowd_now", now())


## Пачка для детали облика: тело (модель|тон) или причёска (имя|модель|цвет)
func _group(key: String, mesh: Mesh, mat: Material) -> Dictionary:
	if groups.has(key):
		return groups[key]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = 16
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var g := {"mm": mm, "mi": mi, "who": []}
	groups[key] = g
	return g


func _grow(g: Dictionary) -> void:
	var mm: MultiMesh = g["mm"]
	var n: int = (g["who"] as Array).size()
	if n < mm.instance_count:
		return
	var cap := mm.instance_count * 2
	var buf := mm.buffer
	var nm := MultiMesh.new()
	nm.transform_format = MultiMesh.TRANSFORM_3D
	nm.use_colors = true
	nm.use_custom_data = true
	nm.mesh = mm.mesh
	nm.instance_count = cap
	buf.resize(cap * 20)
	nm.buffer = buf
	nm.visible_instance_count = n
	g["mm"] = nm
	(g["mi"] as MultiMeshInstance3D).multimesh = nm


## Человек толпы по облику жителя (Citizen.roll_look): xf — где стоят его ступни (масштаб — свой), clip — что делает
func add(lk: Dictionary, xf: Transform3D, clip := "sit", t0 := INF, child := false) -> Dictionary:
	var mdl := String(lk.get("mdl", Citizen.PLEBS[0]))
	var R := rig(mdl)
	var variant := String(lk.get("skin", "A"))
	var female := mdl in Citizen.FEMALE
	var cols := Citizen._cols_of(lk)
	var k := float(R["k"])
	var ci := [0, 0, 0]
	if cols.size() == 3:
		var main: Color = cols[0]
		main = Color(minf(main.r * k, 1.0), minf(main.g * k, 1.0), minf(main.b * k, 1.0))
		# как у жителя (Citizen._paint): там цвет уходит в instance uniform уже линейным, и Godot переводит его ещё раз —
		# чтобы ткани на трибунах были того же тона, что на улице, переводим дважды
		ci = [pal(main.srgb_to_linear().srgb_to_linear()), pal((cols[1] as Color).srgb_to_linear().srgb_to_linear()),
			pal((cols[2] as Color).srgb_to_linear().srgb_to_linear())]
	var p := {"lk": lk, "parts": [], "clip": clip_id(clip), "t0": now() if t0 == INF else t0, "prev": 0.0, "ts": -100.0,
		"xf": xf, "s": SIZE * (0.68 if child else 1.0), "ci": ci, "hc": 0}
	_put(p, "b|%s|%s" % [mdl, variant], R["body"], _material("body", R, variant))
	# причёска, борода, венок — как у жителя (Citizen._put_hair)
	var hairs := []
	var h := int(lk.get("hair", 1))
	if female:
		hairs.append("SM_Chr_Hair_Female_0%d" % clampi(h, 1, 6))
	elif h > 0:
		hairs.append("SM_Chr_Hair_Male_0%d" % clampi(h, 1, 7))
	if not female and not child and int(lk.get("beard", 0)) > 0:
		hairs.append("SM_Chr_Hair_Beard_0%d" % clampi(int(lk["beard"]), 1, 4))
	if not child and int(lk.get("crown", 0)) > 0:
		hairs.append("SM_Chr_Attach_Crown_Leaf_0%d" % clampi(int(lk["crown"]), 1, 2))
	var hc := String(lk.get("hc", ""))
	for hn: String in hairs:
		var crown := hn.contains("Crown")
		var flat := not crown and (hc == "C" or hc == "S")
		var atlas := variant
		if not crown and not flat:
			atlas = "C" if hc == "B" else ("A" if hc == "A" else variant)
		if flat:
			var col: Color = Color("d2cdc4") if hc == "S" else Citizen.HAIR_BLOND[1 if hn.contains("Beard") else 0]
			p["hc"] = pal(col.srgb_to_linear())
		_put(p, "h|%s|%s|%s" % [hn, mdl, "flat" if flat else atlas], hair_mesh(hn, mdl), _material("hair", R, atlas, flat))
	_write(p)
	return p


func _put(p: Dictionary, key: String, mesh: Mesh, mat: Material) -> void:
	var g := _group(key, mesh, mat)
	_grow(g)
	var who: Array = g["who"]
	var part := [key, who.size()]
	who.append([p, part])
	(g["mm"] as MultiMesh).visible_instance_count = who.size()
	(p["parts"] as Array).append(part)


func _write(p: Dictionary) -> void:
	var xf: Transform3D = p["xf"]
	xf.basis = xf.basis.orthonormalized().scaled(Vector3.ONE * float(p["s"]))
	var ci: Array = p["ci"]
	var col := Color(ci[0] / 255.0, ci[1] / 255.0, ci[2] / 255.0, int(p["hc"]) / 255.0)
	var cu := Color(float(p["clip"]), float(p["t0"]), float(p["prev"]), float(p["ts"]))
	for part: Array in p["parts"]:
		var mm: MultiMesh = groups[part[0]]["mm"]
		var i: int = part[1]
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, col)
		mm.set_instance_custom_data(i, cu)


## Сменить движение (плавно, за BLEND с). phase — с какой доли круга начать (−1 — с начала)
func play(p: Dictionary, clip: String, phase := 0.0) -> void:
	var c := clip_id(clip)
	var t := now()
	if c == int(p["clip"]) and phase < 0.0:
		return
	var old: Array = _clip_tab[int(p["clip"])]
	var L := float(old[1]) / float(old[3])
	var ph := clampf(fmod(maxf(t - float(p["t0"]), 0.0), L) / L if old[2] > 0.5 else minf((t - float(p["t0"])) / L, 0.999), 0.0, 0.999)
	p["prev"] = float(p["clip"]) + ph
	p["ts"] = t
	p["clip"] = c
	var nl := clip_len(clip)
	p["t0"] = t - maxf(phase, 0.0) * nl
	_write(p)


func move(p: Dictionary, xf: Transform3D) -> void:
	p["xf"] = xf
	_write(p)


func remove(p: Dictionary) -> void:
	for part: Array in p["parts"]:
		var g: Dictionary = groups[part[0]]
		var who: Array = g["who"]
		var mm: MultiMesh = g["mm"]
		var i: int = part[1]
		var last := who.size() - 1
		if i != last:
			var moved: Array = who[last]
			who[i] = moved
			(moved[1] as Array)[1] = i
			mm.set_instance_transform(i, mm.get_instance_transform(last))
			mm.set_instance_color(i, mm.get_instance_color(last))
			mm.set_instance_custom_data(i, mm.get_instance_custom_data(last))
		who.pop_back()
		mm.visible_instance_count = who.size()
	p["parts"] = []


## Тени от толпы: вблизи — да, издали их не видно, а считаются они дорого (каждый человек — ещё раз в карту теней)
var shadows := true


func set_shadows(on: bool) -> void:
	if on == shadows:
		return
	shadows = on
	for k in groups:
		(groups[k]["mi"] as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func count() -> int:
	var n := 0
	for k in groups:
		if String(k).begins_with("b|"):
			n += (groups[k]["who"] as Array).size()
	return n


func clear() -> void:
	for k in groups:
		(groups[k]["mi"] as Node).queue_free()
	groups = {}
