extends Node3D
## Выгрузка моделей в .glb для просмотра владельцем (страница с 3D, .work/house_view): наши дома — из чертежей, как
## стоят в готовом городке (дом плебеев, ремесленников, домус), и модель из Higgsfield — упрощённая копия (LOD Godot),
## чтобы страница открывалась быстро. Не для игры.
##   bash .work/py/gpu_run.sh res://test_export_houses.tscn -- [out=D:/CivCity/.work/house_view/models]
##     [glb=D:/CivCity/.work/higgsfield/house/house_tripo.glb] [ratio=0.25 — доля треугольников модели]
##     [name=higgsfield_tripo — имя файла модели] [only_hf=1 — только модель, без наших домов]
var game
var out := "D:/CivCity/.work/house_view/models"
var glb := "D:/CivCity/.work/higgsfield/house/house_tripo.glb"
var ratio := 0.25
var hf_name := "higgsfield_tripo"
var only_hf := false
const TYPES := ["house_pleb", "house_artisan", "house_patrician"]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		match kv[0]:
			"out": out = kv[1]
			"glb": glb = kv[1]
			"ratio": ratio = float(kv[1])
			"name": hf_name = kv[1]
			"only_hf": only_hf = kv[1] == "1"
	DirAccess.make_dir_recursive_absolute(out)
	Game.boot = {"demo": "1", "noui": "1"}
	game = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(game)
	_run()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _export(root: Node3D, path: String) -> void:
	var doc := GLTFDocument.new()
	doc.image_format = "JPEG"
	doc.lossy_quality = 0.88
	var st := GLTFState.new()
	var err := doc.append_from_scene(root, st)
	if err == OK:
		err = doc.write_to_filesystem(st, path)
	var tris := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var ix = arr[Mesh.ARRAY_INDEX]
			tris += (ix.size() if ix != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	print("EXPORT ", path, " err=", err, " tris=", tris, " bytes=", FileAccess.get_file_as_bytes(path).size())


## Наш дом: детали чертежа (Synty и свои меши «#…») узлами — те же, что Parts рисует в городе
func _house(b: Dictionary) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var bp: Bp = game.city.blueprint(b)
	var subst := {"#wall_lamp": "#wall_lamp_dim"}
	for p in bp.parts:
		var nm: String = subst.get(p[0], p[0])
		var n: Node3D
		if nm.begins_with("#"):
			var mi := MeshInstance3D.new()
			mi.mesh = Parts._special_mesh(nm)
			n = mi
		else:
			n = Synty.make(nm, p[2])
		root.add_child(n)
		n.transform = p[1]
	return root


## Модель из Higgsfield: LOD Godot (meshoptimizer) с долей ratio, лишние вершины выброшены
func _hf() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(glb, st) != OK:
		print("GLB error")
		return
	var gm: GLTFMesh = st.meshes[0]
	var im: ImporterMesh = gm.mesh
	var full := (im.get_surface_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	var t0 := Time.get_ticks_msec()
	im.generate_lods(60.0, 25.0, [])
	var best := -1
	var best_d := 1e9
	for i in im.get_surface_lod_count(0):
		var n := im.get_surface_lod_indices(0, i).size()
		print("LOD ", i, " tris ", n / 3, " (", snappedf(float(n) / full * 100.0, 0.1), "%)")
		var d := absf(float(n) / full - ratio)
		if d < best_d:
			best_d = d
			best = i
	print("LODs in ", Time.get_ticks_msec() - t0, " ms; full tris ", full / 3, ", pick ", best)
	var arr := im.get_surface_arrays(0)
	var idx: PackedInt32Array = im.get_surface_lod_indices(0, best) if best >= 0 else arr[Mesh.ARRAY_INDEX]
	var vin: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nin = arr[Mesh.ARRAY_NORMAL]
	var uin = arr[Mesh.ARRAY_TEX_UV]
	var remap := PackedInt32Array()
	remap.resize(vin.size())
	remap.fill(-1)
	var v := PackedVector3Array()
	var nn := PackedVector3Array()
	var uv := PackedVector2Array()
	var ni := PackedInt32Array()
	ni.resize(idx.size())
	for k in idx.size():
		var o := idx[k]
		var r := remap[o]
		if r < 0:
			r = v.size()
			remap[o] = r
			v.append(vin[o])
			if nin != null:
				nn.append(nin[o])
			if uin != null:
				uv.append(uin[o])
		ni[k] = r
	var out_arr := []
	out_arr.resize(Mesh.ARRAY_MAX)
	out_arr[Mesh.ARRAY_VERTEX] = v
	if nin != null:
		out_arr[Mesh.ARRAY_NORMAL] = nn
	if uin != null:
		out_arr[Mesh.ARRAY_TEX_UV] = uv
	out_arr[Mesh.ARRAY_INDEX] = ni
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arr)
	am.surface_set_material(0, im.get_surface_material(0))
	var root := Node3D.new()
	add_child(root)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	root.add_child(mi)
	print("HF verts ", v.size(), " tris ", ni.size() / 3)
	_export(root, "%s/%s.glb" % [out, hf_name])


func _run() -> void:
	while not game.ready_done:
		await frames(5)
	await frames(10)
	game.speed = 0.0
	var c = game.city
	var pick := {}
	for id in c.buildings:
		var b: Dictionary = c.buildings[id]
		var t: String = b["type"]
		if t in TYPES and (not pick.has(t) or int(b.get("tier", 1)) > int(pick[t].get("tier", 1))):
			pick[t] = b
	for t in TYPES:
		if pick.has(t) and not only_hf:
			print("HOUSE ", t, " id ", pick[t]["id"], " tier ", pick[t].get("tier", 1), " variant ", pick[t].get("variant", 0))
			_export(_house(pick[t]), "%s/%s.glb" % [out, t])
	_hf()
	get_tree().quit()
