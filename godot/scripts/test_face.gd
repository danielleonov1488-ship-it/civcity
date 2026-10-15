extends Node3D
## Стенд лиц вблизи: персонаж Synty как есть (материал из FBX и атлас Synty с картой нормалей) рядом с нашим жителем
## (шейдер одежды, простой материал режима совместимости, ребёнок с крупной головой) — тот же свет, та же камера.
## Снимки — .work/face/face_<n>.png. Аргументы (после --): out=папка  fix=0|1 (1 — с правкой лица Citizen.face_fix).
var out := "D:/CivCity/.work/face/"
var fix := true
const MODEL := "SK_Chr_Worker_Male_01"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out" and kv.size() > 1:
			out = kv[1].trim_suffix("/") + "/"
		if kv[0] == "fix" and kv.size() > 1:
			fix = kv[1] != "0"
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _world() -> Camera3D:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e8d3a6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1d8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 35, 0)
	key.light_energy = 1.25
	add_child(key)
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.near = 0.02
	add_child(cam)
	cam.current = true
	return cam


## Тело персонажа с волосами; mat — материал для всех сеток (null — как в FBX)
func _body(mat: Material, hair_mat: Material, model := MODEL, hair := "SM_Chr_Hair_Male_02") -> Node3D:
	var b := (load(Citizen.DIR + model + ".fbx") as PackedScene).instantiate() as Node3D
	add_child(b)
	for mi: MeshInstance3D in b.find_children("*", "MeshInstance3D", true, false):
		if mat != null:
			mi.material_override = mat
	var sk: Skeleton3D = b.find_children("*", "Skeleton3D", true, false)[0]
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	sk.add_child(att)
	var hn := (load("res://assets/synty/FBX/Attachments/%s.fbx" % hair) as PackedScene).instantiate() as Node3D
	for mi: MeshInstance3D in hn.find_children("*", "MeshInstance3D", true, false):
		if hair_mat != null:
			mi.material_override = hair_mat
	att.add_child(hn)
	return b


func _run() -> void:
	Synty._index()
	var cam := _world()
	var atlas: Texture2D = load(Synty._tex_path("PolygonAncientEmpire_01_A"))
	var syn := StandardMaterial3D.new()           # материал Synty: атлас и карта нормалей, как в их списке материалов
	syn.albedo_texture = atlas
	syn.normal_enabled = true
	syn.normal_texture = load(Synty._tex_path("PolygonAncientEmpire_01_Normals"))
	syn.roughness = 0.85
	var subjects := []
	subjects.append(["fbx", _body(null, null)])
	subjects.append(["synty", _body(syn, syn)])
	var ours := _body(Citizen._material("A"), Citizen._plain("A"))
	Citizen._dress(ours, MODEL, "plebs", false, false, RandomNumberGenerator.new())
	subjects.append(["ours", ours])
	subjects.append(["compat", _body(Citizen._plain("A"), Citizen._plain("A"))])
	var kid := _body(Citizen._material("A"), Citizen._plain("A"))
	Citizen._dress(kid, MODEL, "plebs", false, true, RandomNumberGenerator.new())
	kid.scale = Vector3.ONE * 0.68
	People.kid_look(kid)
	subjects.append(["kid", kid])
	var fem := _body(Citizen._material("B"), Citizen._plain("B"), "SK_Chr_Worker_Female_01", "SM_Chr_Hair_Female_02")
	Citizen._dress(fem, "SK_Chr_Worker_Female_01", "artisans", true, false, RandomNumberGenerator.new())
	subjects.append(["fem", fem])
	var dark := _body(Citizen._material("C"), Citizen._plain("C"))
	Citizen._dress(dark, MODEL, "plebs", false, false, RandomNumberGenerator.new())
	subjects.append(["dark", dark])
	var old := _body(Citizen._material("A"), Citizen._plain("A"))
	Citizen._dress(old, MODEL, "plebs", false, false, RandomNumberGenerator.new())
	subjects.append(["old", old])
	if fix:
		for s: Array in subjects:
			match String(s[0]):
				"fbx":
					pass
				"old":
					Citizen.elder_look(s[1])
				"kid":
					Citizen.face_fix(s[1], false, true)
				_:
					Citizen.face_fix(s[1])
	for i in subjects.size():
		(subjects[i][1] as Node3D).position = Vector3(i * 3.0, 0, 0)
		(subjects[i][1] as Node3D).visible = false
	DirAccess.make_dir_recursive_absolute(out)
	for i in subjects.size():
		var n: Node3D = subjects[i][1]
		for s: Array in subjects:
			(s[1] as Node3D).visible = s[1] == n
		var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
		var hb := sk.find_bone("Head")
		await frames(3)
		var head := (sk.global_transform * sk.get_bone_global_pose(hb)).origin + Vector3(0, 0.05, 0) * n.scale.y
		for v in 2:
			var dir := Vector3(0, 0.05, 1).normalized() if v == 0 else Vector3(sin(0.32), 0.12, cos(0.32)).normalized()
			cam.position = head + dir * 1.3 * n.scale.y
			cam.look_at(head - Vector3(0, 0.02, 0), Vector3.UP)
			await frames(8)
			var img := get_viewport().get_texture().get_image()
			var w := img.get_width()
			var h := img.get_height()
			var sz := mini(w, h)
			img = img.get_region(Rect2i(w / 2 - sz / 2, h / 2 - sz / 2, sz, sz))
			img.save_png(out + "face_%s_%d%s.png" % [subjects[i][0], v, "" if fix else "_raw"])
			print("SHOT face_%s_%d" % [subjects[i][0], v])
	print("FACE DONE")
	get_tree().quit()
