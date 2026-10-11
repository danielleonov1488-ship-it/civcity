class_name SyntyBatch
extends RefCounted
## Пачка одинаковых деталей Synty: все копии одной модели (с одной раскраской) рисуются одним вызовом
## через MultiMesh — сотни домов и деревьев без тормозов.

var groups := {}        # ключ → {name, remap, xf: [Transform3D]}


func add(name: String, xf: Transform3D, remap := {}) -> void:
	var key := name + "|" + str(remap)
	if not groups.has(key):
		groups[key] = {"name": name, "remap": remap, "xf": []}
	groups[key]["xf"].append(xf)


## Собрать всё в узлы-пачки под parent
func build(parent: Node3D, shadows := true) -> int:
	var count := 0
	for key in groups:
		var g: Dictionary = groups[key]
		var src := Synty.make(g["name"], g["remap"])
		for mi: MeshInstance3D in src.find_children("*", "MeshInstance3D", true, false):
			var local := Citizen._rel(mi, src)
			# сетка с уже назначенными материалами
			var mesh := mi.mesh.duplicate() as Mesh
			for s in mesh.get_surface_count():
				var m := mi.get_surface_override_material(s)
				if m:
					mesh.surface_set_material(s, m)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			var xs: Array = g["xf"]
			mm.instance_count = xs.size()
			for i in xs.size():
				mm.set_instance_transform(i, (xs[i] as Transform3D) * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mmi)
			count += xs.size()
		src.free()
	return count
