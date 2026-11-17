extends RefCounted
## Передняя сторона украшения в осях чертежа, до поворота постройки.


static func front(bp: Bp, type: String) -> Dictionary:
	for part: Array in bp.parts:
		var model := String(part[0])
		if model.begins_with("SM_Prop_Seat_Bench"):
			var xf: Transform3D = part[1]
			var box := Bp.model_aabb(model)
			return {"at": xf * Vector3(box.get_center().x, 0, box.get_center().z), "front": xf.basis.z.normalized()}
	if Defs.base_of(type) in ["statue", "bust", "altar", "lararium", "sundial", "rosearch", "trellis", "smallfountain"]:
		return {"at": Vector3.ZERO, "front": Vector3.BACK}
	return {}
