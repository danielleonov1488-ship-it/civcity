extends SceneTree
## Проверка .glb из Blender: какие материалы и флаги ставит импорт glTF (цвет вершин, текстура, прозрачность)
##   bash tools/godot.sh --headless --path godot --script res://scripts/test_kit_probe.gd -- glb=D:/…/pleb_A2.glb
##   … -- kit=K:pleb_0_2/House   — деталь своего набора, как её видит игра (KitLib)
func _init() -> void:
	var path := ""
	var kit := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("glb="):
			path = a.substr(4)
		if a.begins_with("kit="):
			kit = a.substr(4)
	if kit != "":
		var m := KitLib._mesh(kit)
		print("KIT ", kit, " mesh ", m)
		if m:
			for s in m.get_surface_count():
				var arr := m.surface_get_arrays(s)
				var cols = arr[Mesh.ARRAY_COLOR]
				print("  surf ", s, " mat ", m.surface_get_material(s).resource_name, " verts ", (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
					" cols ", (cols as PackedColorArray).size() if cols is PackedColorArray else 0,
					" sample ", (cols as PackedColorArray)[0] if cols is PackedColorArray and (cols as PackedColorArray).size() > 0 else null)
		quit()
		return
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	print("load ", doc.append_from_file(path, st))
	var root: Node = doc.generate_scene(st)
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.name != "House" and mi.name != "Door_0" and mi.name != "Door.0":
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s)
			var arr := mi.mesh.surface_get_arrays(s)
			var cols = arr[Mesh.ARRAY_COLOR]
			print(mi.name, " surf ", s, " mat ", m, " ", (m as BaseMaterial3D).vertex_color_use_as_albedo if m is BaseMaterial3D else "-",
				" srgb ", (m as BaseMaterial3D).vertex_color_is_srgb if m is BaseMaterial3D else "-",
				" tex ", (m as BaseMaterial3D).albedo_texture if m is BaseMaterial3D else "-", " cols ", (cols as PackedColorArray).size() if cols else 0)
	quit()
