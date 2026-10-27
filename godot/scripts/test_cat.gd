extends Node3D
## Кошки рядом с жителем в настоящей игре и её свете. Запуск: bash .work/py/gpu_run.sh res://test_cat.tscn
## Слева — прежние кошки из Kit, справа — новые (модель Quaternius) того же окраса и в той же позе:
## идёт, сидит, гладят, спит → cats_day.png, cats_night.png; все окрасы во всех позах → cats_poses_day/night.png;
## крупно новые → cats_close.png, спящие → cats_sleep.png, как видно в игре → cats_zoom.png. Проверки: модель загрузилась, пауза останавливает движение, скорость — как у игры.
var game
var fails := 0
const X0 := 186.0
const Z0 := 140.0
const OUT := "D:/CivCity/.work/gd/"


func _ready() -> void:
	Game.boot = {"new": "1", "noui": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func check(ok: bool, what: String) -> void:
	print("CAT %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


## Сид, при котором первый rng.randi() даёт нужный окрас (и прежняя, и новая кошка берут окрас первым)
func _seed_for(fur: int) -> int:
	var r := RandomNumberGenerator.new()
	for s in range(1, 1000):
		r.seed = s
		if r.randi() % People.CAT_FURS.size() == fur:
			return s
	return 1


func _cat(home: Dictionary, fur: int, kit: bool, p: Vector2, yaw: float, state: String) -> Dictionary:
	var ppl = game.people
	ppl.rng.seed = _seed_for(fur)
	var c: Dictionary = ppl._make_cat_kit(home) if kit else ppl._make_cat(home)
	c["p"] = p
	c["yaw"] = yaw
	c["state"] = state
	c["walk"] = 1.0 if state == "walk" else 0.0
	ppl._cat_place(c)
	if c.has("anim"):
		c["clip"] = ""
		ppl._cat_anim(c)
		(c["anim"] as AnimationPlayer).seek(0.45, true)
	else:
		for i in 3:
			ppl._cat_kit_anim(c, 1.0, 0.13)
	ppl.cats.append(c)
	return c


func _person(seed: int, p: Vector2, yaw: float, clip: String, child := false) -> Citizen:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var c := Citizen.create(rng, seed % 2 == 0, child)
	game.actors_root.add_child(c)
	c.position = Vector3(p.x, game.land.height_at(p.x, p.y), p.y)
	c.rotation.y = yaw
	c.play(clip, 0.0)
	c.anim.seek(0.8, true)
	c.anim.speed_scale = 0.0
	return c


func _shot(name: String, look: Vector3, off: Vector3) -> void:
	look.y = game.land.height_at(look.x, look.z) + look.y
	game.rig.cine_look(look + off, look)
	await frames(45)
	get_viewport().get_texture().get_image().save_png(OUT + name)
	print("CAT saved ", OUT + name)


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	game.hud.visible = false
	game.speed = 0.0
	game.clock_hours = false
	game.rig.cine = true
	var ppl = game.people
	var city = game.city
	check(People._cat_model_ok(), "модель кошки загрузилась (%s)" % People.CAT_FILE)
	if People._cat_lib:
		print("CAT clips ", People._cat_lib.get_animation_list(), " size ", People._cat_size)
	# дом для кошек и мостовая под ними; деревья и кусты вокруг убрать — не заслоняют
	game.clear_nature(Vector2(X0 + 6.0, Z0 + 2.0), 16.0)
	game.land.paint_line(Vector2(X0 - 5.0, Z0 + 0.3), Vector2(X0 + 17.0, Z0 + 0.3), 3.2, Land.Kind.PLAZA, true)
	var home := {}
	for z in range(int(Z0) - 10, int(Z0) - 4):
		var pl: Dictionary = game.placement("house_pleb", Vector2(X0, z))
		if pl["err"] == "":
			home = city.place("house_pleb", pl["pos"], pl["yaw"], pl["variant"], pl["color"])
			break
	if home.is_empty():
		home = city.buildings.values()[0]
	await frames(5)
	# прежние слева, новые справа, житель посередине; пары одного окраса: идёт, сидит, гладят, спит
	var side := PI / 2 + 0.45                         # три четверти к камере
	var pairs := [[0, "walk"], [1, "sit"], [5, "pet"], [3, "sleep"]]
	for i in pairs.size():
		var fur: int = pairs[i][0]
		var st: String = pairs[i][1]
		_cat(home, fur, true, Vector2(X0 - 4.4 + i * 1.0, Z0 + 0.2), side, st)
		_cat(home, fur, false, Vector2(X0 + 0.8 + i * 0.75, Z0 + 0.2), side, st)
	_person(11, Vector2(X0 - 0.05, Z0 - 0.1), 0.25, "Idle_Loop")
	# гладят: ребёнок присел у кошки (у прежней и у новой)
	_person(12, Vector2(X0 - 4.4 + 2 * 1.0 + 0.05, Z0 - 0.35), -0.1, "Crouch_Idle", true)
	_person(14, Vector2(X0 + 0.8 + 2 * 0.75 + 0.05, Z0 - 0.3), -0.1, "Crouch_Idle", true)
	# все окрасы во всех позах — только новые
	var states := ["walk", "sit", "pet", "sleep"]
	for f in People.CAT_FURS.size():
		for s in states.size():
			_cat(home, f, false, Vector2(X0 + 9.0 + f * 0.75, Z0 - 0.6 + s * 0.75), side, states[s])
	await frames(10)
	# где кости у новой кошки в каждой позе (в единицах модели): для подгонки поз
	for st: String in states:
		var cc: Dictionary = ppl.cats[8 + states.find(st)]
		var sk: Skeleton3D = (cc["n"] as Node3D).find_children("*", "Skeleton3D", true, false)[0]
		var s := ""
		for bn in ["Bone", "Bone.003", "Bone.003_end", "Bone.016", "Bone.010", "Bone.004", "Bone.005", "Bone.006", "Bone.007", "Bone.007_end"]:
			var o := sk.get_bone_global_pose(sk.find_bone(bn)).origin * 100.0
			s += "%s(%.2f,%.2f,%.2f) " % [bn.trim_prefix("Bone"), o.x, o.y, o.z]
		print("CAT bones %s: %s" % [st, s])
	for h: Array in [[12.5, "day"], [22.5, "night"]]:
		game._set_hour(float(h[0]))
		await frames(5)
		await _shot("cats_%s.png" % h[1], Vector3(X0 - 0.85, 0.45, Z0 + 0.2), Vector3(0.0, 1.5, 8.0))
		await _shot("cats_poses_%s.png" % h[1], Vector3(X0 + 10.9, 0.2, Z0 + 0.5), Vector3(0.0, 2.6, 4.6))
	game._set_hour(12.5)
	await _shot("cats_zoom.png", Vector3(X0 - 0.5, 0.3, Z0 + 0.2), Vector3(0.0, 8.0, 12.0))      # обычный крупный план игры
	await _shot("cats_sleep.png", Vector3(X0 + 10.0, 0.08, Z0 + 1.65), Vector3(0.6, 1.1, 2.0))
	await _shot("cats_close.png", Vector3(X0 + 1.9, 0.18, Z0 + 0.2), Vector3(0.0, 0.85, 2.9))
	# пауза: движение стоит; ход — идёт со скоростью игры
	var c: Dictionary = ppl.cats[ppl.cats.size() - 1]
	var ap: AnimationPlayer = c.get("anim")
	if ap:
		game.speed = 1.0
		await frames(20)
		var p0 := ap.current_animation_position
		var k1 := ap.speed_scale
		game.speed = 3.0
		await frames(5)
		check(is_equal_approx(ap.speed_scale, k1 * 3.0) and k1 > 0.0, "скорость движения — как у игры (x1 %.2f, x3 %.2f)" % [k1, ap.speed_scale])
		game.speed = 0.0
		await frames(3)
		p0 = ap.current_animation_position
		await frames(20)
		check(ap.speed_scale == 0.0 and is_equal_approx(p0, ap.current_animation_position), "пауза останавливает кошек")
		# шаг: лапы не скользят — скорость клипа × длина шага = скорость кошки
		var w: Dictionary = ppl.cats[16]
		print("CAT walk k=%.2f clip=%s" % [float(w.get("k", 0.0)), w.get("clip", "")])
	await _kitten(home)
	print("CAT DONE fails=%d cats=%d" % [fails, ppl.cats.size()])
	get_tree().quit()


# ---------- кошка «Kitten» на скелете Quaternius (27.10) ----------

## Узлы живой кошки (или cat_node): скелет, сетка
func _parts(root: Node3D) -> Array:
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	return [sk, mi]


## Сетка кошки в позе сейчас — как её гнёт видеокарта (вершины в осях скелета: x — вперёд, y — влево, z — вверх)
func _posed(sk: Skeleton3D, mi: MeshInstance3D) -> PackedVector3Array:
	var arr := mi.mesh.surface_get_arrays(0)
	var skin: Skin = mi.skin
	var mats: Array[Transform3D] = []
	for b in skin.get_bind_count():
		mats.append(sk.get_bone_global_pose(sk.find_bone(skin.get_bind_name(b))) * skin.get_bind_pose(b))
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var B: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var W: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var out := PackedVector3Array()
	out.resize(V.size())
	for i in V.size():
		var p := Vector3.ZERO
		for k in 4:
			p += (mats[B[i * 4 + k]] * V[i]) * W[i * 4 + k]
		out[i] = p
	return out


## Растяжение рёбер граней в позе (posed) против покоя (rest): [самое длинное / в покое, самое короткое / в покое];
## без глаз (их грани — доли миллиметра)
func _stretch(rest: PackedVector3Array, posed: PackedVector3Array, col: PackedColorArray) -> Vector2:
	var mx := 0.0
	var mn := INF
	for t in range(0, rest.size(), 3):
		if col[t].r > 0.7:
			continue
		for e in 3:
			var a := t + e
			var b := t + (e + 1) % 3
			var l0 := rest[a].distance_to(rest[b])
			if l0 < 0.0004:
				continue
			var r := posed[a].distance_to(posed[b]) / l0
			mx = maxf(mx, r)
			mn = minf(mn, r)
	return Vector2(mx, mn)


## Сантиметры на улице из единиц скелета
func _cm(v: float) -> float:
	return v * 100.0 * People.CAT_LEN / (People._cat_size / 100.0)


func _kitten(home: Dictionary) -> void:
	var ppl = game.people
	var mesh: ArrayMesh = People._cat_v2
	check(mesh != null and mesh.get_surface_count() == 1, "сетка «Kitten» собрана (%s)" % People.CAT_MESH)
	if mesh == null:
		return
	var arr := mesh.surface_get_arrays(0)
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var W: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var wok := W.size() == V.size() * 4
	for i in V.size():
		if not wok:
			break
		var s := W[i * 4] + W[i * 4 + 1] + W[i * 4 + 2] + W[i * 4 + 3]
		wok = absf(s - 1.0) < 0.001
	var eyes := 0
	var parts := {}
	for c: Color in col:
		eyes += 1 if c.r > 0.7 else 0
		parts["%.2f" % c.r] = true
		parts["g%.1f" % c.g] = true
		parts["b%.2f" % c.b] = true
	check(V.size() == 650 * 3 and wok and People._cat_skin.get_bind_count() == People.CAT_NEXT.size(),
		"сетка на скелете: %d треугольников, веса костей у всех вершин (сумма 1), привязок %d" % [V.size() / 3, People._cat_skin.get_bind_count()])
	check(eyes >= 60 and parts.size() >= 11, "в вершинах — части тела, «маска», места на теле, глаза (%d вершин глаз; %s)" % [eyes, str(parts.keys())])
	# живая кошка: сетка «Kitten», привязка, суставы под неё; длина на улице — как прежде (около CAT_LEN)
	var c: Dictionary = ppl._make_cat(home, {"fur": 0, "p": Vector2(X0 + 2.0, Z0 + 4.0), "rng": RandomNumberGenerator.new()})
	var pr := _parts(c["n"])
	var sk: Skeleton3D = pr[0]
	var mi: MeshInstance3D = pr[1]
	var J := People._cat_joints()
	var head_ok: bool = (sk.get_bone_global_rest(sk.find_bone("Bone.003")).origin - (J["Bone.003"] as Vector3)).length() < 0.0001
	check(mi.mesh == mesh and mi.skin == People._cat_skin and head_ok, "у кошки — сетка «Kitten» и её привязка, суставы под неё")
	var box := Artisau.aabb((c["n"] as Node3D).get_child(0))
	var L := maxf(box.size.x, box.size.z)
	check(L > People.CAT_LEN * 0.85 and L < People.CAT_LEN * 1.07, "длина кошки на улице %.2f м (CAT_LEN %.2f)" % [L, People.CAT_LEN])
	# все движения: идут (кости двигаются), сетка не рвётся и не тянется, в землю не уходит, лапы в шаге ступают по земле
	var ap: AnimationPlayer = c["anim"]
	for st: String in ["walk", "sit", "pet", "sleep"]:
		c["state"] = st
		c["clip"] = ""                            # без плавного перехода: на паузе он не идёт
		ppl._cat_anim(c)
		ap.speed_scale = 0.0
		var cl := String(People.CAT_CLIP[st][0])
		var Lc := ap.current_animation_length
		var worst := Vector2(0.0, INF)
		var low := INF
		var high := -INF
		var leg_low := INF
		var moved := 0.0
		var prev := PackedVector3Array()
		for f in 8:
			ap.seek(Lc * f / 8.0, true)
			await frames(2)                       # позы костей скелет пересчитывает к кадру
			var ps := _posed(sk, mi)
			var sr := _stretch(V, ps, col)
			worst = Vector2(maxf(worst.x, sr.x), minf(worst.y, sr.y))
			var fl := INF
			for i in ps.size():
				if absf(col[i].b - 0.25) < 0.05:
					leg_low = minf(leg_low, ps[i].z)          # лапы
				else:
					low = minf(low, ps[i].z)                  # туловище, голова, хвост
				fl = minf(fl, ps[i].z)
			high = maxf(high, fl)
			if not prev.is_empty():
				for i in range(0, ps.size(), 7):
					moved = maxf(moved, ps[i].distance_to(prev[i]))
			prev = ps
		print("CAT kitten %s: stretch %.2f…%.2f, lowest body %.1f cm, legs %.1f cm, highest lowest %.1f cm, moved %.4f" % [cl, worst.y, worst.x, _cm(low), _cm(leg_low), _cm(high), moved])
		check(ap.current_animation == "cat/" + cl and moved > 0.0002, "«%s» играет (кости двигаются)" % cl)
		# сгиб сжимает внутреннюю сторону сустава (локоть, скакательный сустав сложены) — это можно, но не в точку
		check(worst.x < 2.3 and worst.y > 0.12, "«%s»: грани не рвутся и не тянутся (рёбра от %.2f до %.2f длины в покое)" % [cl, worst.y, worst.x])
		# спит — туловище на земле, сложенные лапы под ним могут уйти в землю (их не видно); в остальных — и лапы на земле
		var leg_lim := -7.0 if st == "sleep" else -1.5
		check(_cm(low) > -1.5 and _cm(leg_low) > leg_lim and _cm(high) < 1.5,
			"«%s»: стоит/лежит на земле — не тонет и не висит (туловище %.1f см, лапы %.1f см, в каждом кадре касается земли)" % [cl, _cm(low), _cm(leg_low)])
	# все окрасы: свои шерсть и узор; глаза не цвета шерсти; Мася — с отливом, сиамская — с «маской»
	var furs := []
	for f in People.CAT_FURS.size():
		furs.append(f)
	furs.append_array([People.CAT_MASYA, People.CAT_SIAMESE])
	var seen := {}
	for f: int in furs:
		var cf: Dictionary = ppl._make_cat(home, {"fur": f, "p": Vector2(X0 + 3.0, Z0 + 4.0), "rng": RandomNumberGenerator.new()})
		var mt: ShaderMaterial = cf["mat"]
		var fc: Color = mt.get_shader_parameter("fur")
		var ec: Color = mt.get_shader_parameter("eye_col")
		var ok: bool = fc.is_equal_approx(People.cat_fur(f)[0]) and int(mt.get_shader_parameter("pattern")) == int(People.cat_look(f)[0]) \
			and Vector3(fc.r - ec.r, fc.g - ec.g, fc.b - ec.b).length() > 0.1 and int(cf["fi"]) == f
		if f == People.CAT_MASYA:
			ok = ok and float(mt.get_shader_parameter("sheen")) > 0.3
		if f == People.CAT_SIAMESE:
			ok = ok and int(mt.get_shader_parameter("pattern")) == 4
		seen[fc.to_html()] = true
		check(ok, "окрас %d: шерсть %s, узор %d, глаза %s" % [f, fc.to_html(false), int(mt.get_shader_parameter("pattern")), ec.to_html(false)])
		(cf["n"] as Node).queue_free()
	check(seen.size() == furs.size(), "все %d окрасов разные" % furs.size())
	# вещицы лавки: на своей кости, у своего места (голова, шея, спина) — и в позах
	for item: String in Defs.CAT_ITEMS:
		People.cat_wear(c["n"], item)
		var bas := (c["n"] as Node3D).find_children("cat_acc", "BoneAttachment3D", true, false)
		var slot := String(Defs.CAT_ITEMS[item]["slot"])
		var want_bone := String(People.CAT_SLOT[slot][0])
		var ok := bas.size() == 1 and (bas[0] as BoneAttachment3D).bone_name == want_bone
		var far := 0.0
		for st: String in ["walk", "sit", "sleep"]:
			if not ok:
				break
			c["state"] = st
			c["clip"] = ""
			ppl._cat_anim(c)
			ap.speed_scale = 0.0
			ap.seek(0.3, true)
			await frames(1)
			var am: MeshInstance3D = (bas[0] as Node).find_children("cat_acc_mesh", "MeshInstance3D", true, false)[0]
			var cen: Vector3 = am.global_transform * am.mesh.get_aabb().get_center()
			# место крепления в этой позе: точка покоя на кости → туда, где кость сейчас
			var bi := sk.find_bone(want_bone)
			var at: Vector3 = sk.global_transform * (sk.get_bone_global_pose(bi) * sk.get_bone_global_rest(bi).affine_inverse() * ((People.CAT_SLOT[slot][1] as Vector3) * People.CAT_K))
			far = maxf(far, cen.distance_to(at))
		check(ok and far < 0.14, "вещица «%s» (%s): на кости %s, у своего места (до %.1f см)" % [item, slot, want_bone, far * 100.0])
	People.cat_wear(c["n"], "")
	check((c["n"] as Node3D).find_children("cat_acc*", "", true, false).is_empty(), "вещицу можно снять")
	(c["n"] as Node).queue_free()
	# портрет в карточке и кошка в корзинке — та же сетка
	var pn := People.cat_node(People.CAT_MASYA, "Pet", 7)
	var pp := _parts(pn)
	check((pp[1] as MeshInstance3D).mesh == mesh and (pp[1] as MeshInstance3D).skin == People._cat_skin, "портрет и корзинка — тоже «Kitten»")
	pn.free()
	# старые сохранения: окрас и вещица из записи — те же (номера окрасов не менялись)
	for f in [0, 3, 5, People.CAT_MASYA]:
		var rec := {"nm": "Проба", "sx": 1, "fur": f, "home": int(home["id"]), "sd": 12345, "wr": "collar"}
		var lc: Dictionary = ppl._cat_from(rec, home)
		check(int(lc["fi"]) == f, "старая запись: окрас %d остался" % f)
		(lc["n"] as Node).queue_free()
	# новая кошка: поток случайностей жителей — как раньше (дом, имя, окрас, зерно); сиамская — по зерну, не из потока
	ppl.rng.seed = 777
	var r2 := RandomNumberGenerator.new()
	r2.seed = 777
	var nc: Dictionary = ppl._new_cat()
	if not nc.is_empty():
		for i in 4:
			r2.randi()
		var rec: Dictionary = game.city.cats[-1]
		var siam: bool = int(rec["fur"]) == People.CAT_SIAMESE
		var siam_ok: bool = not siam or ((int(rec["sd"]) >> 3) & 1 == 1 and int(nc["fi"]) == People.CAT_SIAMESE)
		check(ppl.rng.state == r2.state and siam_ok, "новая кошка берёт из потока столько же, сколько прежде (окрас %d)" % int(rec["fur"]))
		ppl.drop_cat(nc)
		game.city.cats.pop_back()
	await frames(2)
